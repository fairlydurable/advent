# 8. Concurrency

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/atomic/atomic.mojo, Mojo/stdlib/std/atomic/__init__.mojo, Mojo/stdlib/std/_plugin/_trait.mojo, Mojo/stdlib/std/_plugin/metal/metal_plugin.mojo, Mojo/stdlib/std/memory/arc_pointer.mojo, Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/runtime/__init__.mojo, Mojo/stdlib/std/runtime/_asyncrt.mojo, Mojo/stdlib/std/ffi/__init__.mojo, Mojo/stdlib/std/traits/deinitable.mojo, Mojo/stdlib/std/utils/lock.mojo, Mojo/stdlib/std/collections/list.mojo, max/mojo/max/algorithm/backend/cpu/parallelize.mojo -->

Mojo's origins tell the compiler exactly who may read or write a value inside one thread, and nothing about what a second thread does. This chapter shows where that knowledge stops, what you take on at that point, and how atomics with explicit memory orderings help you carry it.

## Running threads in these samples

The standard library has no public API for starting a thread. The
`std.runtime` package exposes `parallelism_level()` and
`initialize_runtime()`, and its own documentation states that the async task
machinery behind it is unfinished and private. The `parallelize()` function
that most Mojo programs use lives in the MAX package (`max.algorithm`), not in
`std`.

So every threaded sample in this chapter and in chapter 10 starts POSIX
threads directly through FFI, with a small helper module. That choice has a
second benefit: it puts the thread boundary in plain view. A thread's entry
point is a C-ABI function that receives one untyped pointer, and every
guarantee you want across that boundary is one you uphold yourself.

```mojo
# Shared helper for the concurrency samples: POSIX threads through FFI.
# Claims:
#   - The standard library has no thread-spawning API, so these samples
#     call pthread_create and pthread_join from libc.
#   - A thread entry point is a thin, non-capturing C-ABI function. All state
#     a thread sees arrives through one type-erased pointer argument.
#   - `erase` is the single point where a tracked reference becomes an
#     untracked pointer. After it, origins no longer protect the value.
from std.ffi import external_call, c_int
from std.os import abort
from std.testing import assert_equal

comptime ThreadArg = MutOpaquePointer[MutUntrackedOrigin]
comptime ThreadEntry = def(ThreadArg) thin abi("C") -> ThreadArg


def erase[T: AnyType, origin: MutOrigin, //](ref[origin] value: T) -> ThreadArg:
    """Turns a reference into an untracked `void*`. The caller keeps `value`
    alive and unmoved until every thread that received the pointer has joined.
    """
    return (
        Pointer(to=value)
        .unsafe_origin_cast[MutUntrackedOrigin]()
        .unsafe_bitcast[NoneType]()
    )


def spawn(entry: ThreadEntry, arg: ThreadArg) -> Int:
    """Starts a thread running `entry(arg)` and returns its pthread handle."""
    var handle = 0  # pthread_t is pointer-sized on 64-bit macOS and Linux
    var no_attributes: Optional[ThreadArg] = None
    var status = external_call["pthread_create", c_int](
        Pointer(to=handle), no_attributes, entry, arg
    )
    if status != 0:
        abort("pthread_create failed")
    return handle


def join(handle: Int):
    """Blocks until the thread finishes. Joining publishes everything the
    thread wrote to the joining thread."""
    var discarded_result: Optional[ThreadArg] = None
    var status = external_call["pthread_join", c_int](
        handle, Pointer(to=discarded_result)
    )
    if status != 0:
        abort("pthread_join failed")


def run_threads(entry: ThreadEntry, arg: ThreadArg, thread_count: Int):
    """Runs `entry(arg)` on `thread_count` threads and joins them all."""
    var handles = List[Int](capacity=thread_count)
    for _ in range(thread_count):
        handles.append(spawn(entry, arg))
    for handle in handles:
        join(handle)


def record_slot(arg: ThreadArg) abi("C") -> ThreadArg:
    arg.unsafe_bitcast[Int]()[] = 7
    return arg


def main() raises:
    # Self-test: one thread writes a slot the main thread owns.
    var slot = 0
    join(spawn(record_slot, erase(slot)))
    assert_equal(slot, 7)
```

[code/08-concurrency/threads.mojo](code/08-concurrency/threads.mojo)

The samples run on 64-bit macOS and Linux, where `pthread_t` fits in an `Int`.
Each sample imports this module from its own directory.

## 8.1 Races

*Rustonomicon counterpart: 8.1, Races.*

Two different bugs share the word "race":

- A data race: two threads access the same memory at the same time, at least
  one access writes, and at least one access is not atomic. A data race is
  undefined behavior. The program has no meaning after it, not merely a wrong
  answer.
- A race condition: the program's result depends on timing. Every individual
  access can be perfectly synchronized and the logic can still be wrong.

Mojo's type system prevents neither across threads. The rest of this section
shows why, starting with the shape of correct code.

### Disjoint writes need no synchronization

Threads that never touch the same memory cannot race. Here each thread
receives a pointer to its own slot in a `List`, squares it, and returns.
`pthread_join` publishes everything a thread wrote to the thread that joins
it, so the plain reads after the joins see every result.

```mojo
# Claims:
#   - Threads that write disjoint memory do not race, even without atomics.
#   - pthread_join publishes each thread's writes to the joining thread,
#     so plain reads after the join see every result.
#   - Each thread gets its own argument, here a pointer to its own slot.
from threads import ThreadArg, erase, spawn, join
from std.testing import assert_equal


def square_slot(arg: ThreadArg) abi("C") -> ThreadArg:
    var slot = arg.unsafe_bitcast[Int]()
    slot[] = slot[] * slot[]
    return arg


def main() raises:
    var sensor_ids: List[Int] = [3, 5, 8, 13]
    var handles = List[Int]()
    for index in range(len(sensor_ids)):
        handles.append(spawn(square_slot, erase(sensor_ids[index])))
    for handle in handles:
        join(handle)
    assert_equal(sensor_ids, [9, 25, 64, 169])
```

[code/08-concurrency/disjoint_slots.mojo](code/08-concurrency/disjoint_slots.mojo)

### A data race, and its fix

The following snippet is undefined behavior. Several threads increment one
plain `Int` through a shared pointer. Do not run it, and do not reason about
what it prints: a data race has no defined result.

```mojo
# Undefined behavior: a data race on a plain Int.
def count_requests(arg: ThreadArg) abi("C") -> ThreadArg:
    var requests = arg.unsafe_bitcast[Int]()
    for _ in range(INCREMENTS_PER_THREAD):
        requests[] += 1  # load, add, store: three steps, no synchronization
    return arg
```

`Atomic` makes the read-modify-write one indivisible step. On an
`Atomic[Int64]`, `+=` is a `fetch_add`, so the total is exact on every run.

```mojo
# Claims:
#   - Atomic read-modify-write operations make a shared counter exact:
#     8 threads x 10,000 increments always total 80,000.
#   - `+=` on an Atomic is an atomic fetch_add, not a load followed by a store.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic
from std.testing import assert_equal

comptime INCREMENTS_PER_THREAD = 10_000


def count_requests(arg: ThreadArg) abi("C") -> ThreadArg:
    var requests = arg.unsafe_bitcast[Atomic[Int64]]()
    for _ in range(INCREMENTS_PER_THREAD):
        requests[] += 1
    return arg


def main() raises:
    var requests = Atomic[Int64](0)
    run_threads(count_requests, erase(requests), 8)
    assert_equal(requests.load(), 8 * INCREMENTS_PER_THREAD)
```

[code/08-concurrency/atomic_counter.mojo](code/08-concurrency/atomic_counter.mojo)

### A race condition with no data race

Atomics remove data races. They do not remove race conditions. The following
check-then-act sequence uses only atomic operations, so it has defined
behavior, and it still oversells: two threads can both pass the check before
either one acts.

```mojo
# Defined behavior, wrong logic: the check and the act are separate steps.
if office.seats_sold.load() < SEAT_CAPACITY:   # check
    office.seats_sold += 1                     # act
```

The fix makes the check and the act one atomic step with `compare_exchange`.
If another thread changed the count in between, the exchange fails, refreshes
the observed value, and the loop checks capacity again.

```mojo
# Claims:
#   - A race condition is a logic bug, not a data race: a check-then-act
#     sequence of two individually atomic operations can still oversell.
#   - A compare_exchange loop makes the check and the act one atomic step,
#     so 8 threads competing for 500 seats sell exactly 500 and never more.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic
from std.testing import assert_equal

comptime SEAT_CAPACITY = 500
comptime ATTEMPTS_PER_THREAD = 200


struct BoxOffice(Movable):
    var seats_sold: Atomic[Int64]
    var refusals: Atomic[Int64]

    def __init__(out self):
        self.seats_sold = Atomic[Int64](0)
        self.refusals = Atomic[Int64](0)

    def try_reserve(mut self) -> Bool:
        var observed = self.seats_sold.load()
        while observed < SEAT_CAPACITY:
            # On failure, compare_exchange stores the current value into
            # `observed`, so the loop re-checks capacity against fresh data.
            if self.seats_sold.compare_exchange(observed, observed + 1):
                return True
        self.refusals += 1
        return False


def sell_seats(arg: ThreadArg) abi("C") -> ThreadArg:
    var office = arg.unsafe_bitcast[BoxOffice]()
    for _ in range(ATTEMPTS_PER_THREAD):
        _ = office[].try_reserve()
    return arg


def main() raises:
    var office = BoxOffice()
    run_threads(sell_seats, erase(office), 8)
    assert_equal(office.seats_sold.load(), SEAT_CAPACITY)
    assert_equal(office.refusals.load(), 8 * ATTEMPTS_PER_THREAD - SEAT_CAPACITY)
```

[code/08-concurrency/seat_reservation_cas.mojo](code/08-concurrency/seat_reservation_cas.mojo)

### What origins check, and what they do not

Origins enforce two rules that matter here. The first is exclusivity at a
call: one value may not reach two mutable arguments of the same call.

```mojo
# EXPECT-ERROR: one value passed to two `mut` arguments of the same call
# EXPECT-MATCH: aliasing values passed mutably
# Claims:
#   - Within one thread, the compiler rejects passing one value to two
#     mutable arguments of a single call. This is the exclusivity check.
def transfer(mut source: Int, mut destination: Int, amount: Int):
    source -= amount
    destination += amount


def main():
    var balance = 500
    transfer(balance, balance, 120)
```

[code/08-concurrency/aliasing_mut_arguments_fails.mojo](code/08-concurrency/aliasing_mut_arguments_fails.mojo)

That rule covers call arguments, not pointers. Two mutable `Pointer`s to one
value can coexist, and both can write. Holding a mutable pointer never means
"nobody else writes here", and that is exactly the situation every
multithreaded program lives in.

```mojo
# Claims:
#   - The exclusivity check applies to the arguments of a call. Two mutable
#     `Pointer`s to the same value can coexist and both write through it.
#   - So "I hold a mutable pointer" never implies "nobody else can write":
#     sharing state across threads rests on this same fact.
from std.atomic import Atomic
from std.testing import assert_equal


def main() raises:
    var page_views = Atomic[Int64](0)
    var from_frontend = Pointer(to=page_views)
    var from_crawler = Pointer(to=page_views)
    from_frontend[] += 1
    from_crawler[] += 1
    assert_equal(page_views.load(), 2)
```

[code/08-concurrency/two_mut_pointers_compile.mojo](code/08-concurrency/two_mut_pointers_compile.mojo)

Closures look like a way to carry origins across. A `{mut name}` capture is a
reference to the enclosing binding, and a `{var name}` capture is an owned
snapshot taken when you create the closure:

```mojo
# Claims:
#   - A `{mut name}` capture is a reference to the enclosing binding, not a
#     copy: calls to the closure change the original.
#   - A `{var name}` capture is an owned snapshot taken at the moment you create the closure:
#     created: later changes to the original do not reach it.
from std.testing import assert_equal


def main() raises:
    var total_bytes = 0
    var budget = 4096

    def account(packet_bytes: Int) {mut total_bytes}:
        total_bytes += packet_bytes

    def remaining(packet_bytes: Int) {var budget} -> Int:
        return budget - packet_bytes

    account(1500)
    account(576)
    budget = 1024
    assert_equal(total_bytes, 2076)
    assert_equal(remaining(1500), 2596)  # computed from the 4096 snapshot
    assert_equal(budget, 1024)
```

[code/08-concurrency/closure_captures_by_reference.mojo](code/08-concurrency/closure_captures_by_reference.mojo)

But a thread entry point must use the C ABI, and a C-ABI function cannot
capture at all. Everything a thread sees has to arrive through its single
`void*` argument:

```mojo
# EXPECT-ERROR: a C-ABI function cannot capture local state
# EXPECT-MATCH: cannot capture
# Claims:
#   - A thread entry point must be a C-ABI function, and a C-ABI function
#     cannot capture. Shared state has to travel through the opaque argument.
from threads import ThreadArg, erase, run_threads


def main():
    var hits = 0

    def bump(arg: ThreadArg) abi("C") {mut hits} -> ThreadArg:
        hits += 1
        return arg

    run_threads(bump, erase(hits), 4)
```

[code/08-concurrency/capturing_thread_entry_fails.mojo](code/08-concurrency/capturing_thread_entry_fails.mojo)

That argument is where origins end. `erase()` in the helper casts a tracked
reference to `MutUntrackedOrigin`, the origin that "aliases no value the
compiler is managing." From then on the compiler no longer knows the thread
holds the value.

### The erased value dies at its last tracked use

This is the least obvious hazard in the chapter, and it has nothing to do
with timing. Mojo destroys a value right after its last use, and an untracked
pointer does not count as a use. The value you hand to a thread can reach the
end of its life on the very line that hands it off.

This sample records the order of events without ever dereferencing the
dangling pointer:

```mojo
# Claims:
#   - Mojo destroys a value right after its last tracked use (ASAP destruction).
#   - An untracked pointer is not a use: holding one does not keep the
#     value alive. The deinitializer runs before the next line, while the
#     erased pointer still exists.
#   - This sample never dereferences the dangling pointer; it only records
#     the order of events.
from threads import erase
from std.testing import assert_equal


struct JobRecord(Movable):
    var events: Pointer[List[String], MutUntrackedOrigin]

    def __init__(out self, events: Pointer[List[String], MutUntrackedOrigin]):
        self.events = events

    def __deinit__(deinit self):
        self.events[].append("record destroyed")


def main() raises:
    var events = List[String]()
    var event_log = Pointer(to=events).unsafe_origin_cast[MutUntrackedOrigin]()
    var record = JobRecord(event_log)
    var handed_to_thread = erase(record)  # last tracked use of `record`
    events.append("pointer handed off")
    _ = handed_to_thread
    assert_equal(events, ["record destroyed", "pointer handed off"])
```

[code/08-concurrency/erased_pointer_does_not_extend_life.mojo](code/08-concurrency/erased_pointer_does_not_extend_life.mojo)

The same rule applies to values with no deinitializer at all: their storage
stops being theirs at the last use, and the compiler may reuse it. While
writing this chapter, an early version of the histogram sample in section 8.3
crashed for exactly this reason. Its `Histogram` value had no use after
`erase()`, so its stack slot was free while six threads still read it.

The fix is a tracked use after the last join. The builtin `deinit(value^)`
exists for this purpose: it ends the value's life on that line and no
earlier.

```mojo
# Claims:
#   - The fix for early destruction: give the shared value a tracked use
#     after the last join. `deinit(value^)` is a builtin that exists for
#     exactly this: it pins the end of the value's life to that line.
#   - With the value pinned, the thread finishes its work before the
#     deinitializer runs.
from threads import ThreadArg, erase, spawn, join
from std.testing import assert_equal


struct JobRecord(Movable):
    var steps_done: Int
    var events: Pointer[List[String], MutUntrackedOrigin]

    def __init__(out self, events: Pointer[List[String], MutUntrackedOrigin]):
        self.steps_done = 0
        self.events = events

    def __deinit__(deinit self):
        self.events[].append(String("record destroyed after ", self.steps_done, " steps"))


def run_job(arg: ThreadArg) abi("C") -> ThreadArg:
    var record = arg.unsafe_bitcast[JobRecord]()
    for _ in range(3):
        record[].steps_done += 1
    return arg


def main() raises:
    var events = List[String]()
    var event_log = Pointer(to=events).unsafe_origin_cast[MutUntrackedOrigin]()
    var record = JobRecord(event_log)
    var worker = spawn(run_job, erase(record))
    join(worker)
    events.append("worker joined")
    deinit(record^)  # the record's life ends here, not at `erase`
    assert_equal(events, ["worker joined", "record destroyed after 3 steps"])
```

[code/08-concurrency/keep_alive_until_join.mojo](code/08-concurrency/keep_alive_until_join.mojo)

Most samples in this chapter keep their shared value alive by reading it in
an assertion after the join. When nothing reads it afterward, call
`deinit()`.

## 8.2 Send and Sync

*Rustonomicon counterpart: 8.2, Send and Sync.*

Mojo has no `Send` or `Sync` traits, and nothing in their place. The standard
library defines no trait, attribute, or conformance that marks a type as safe
to move to another thread or safe to share between threads, and the compiler
performs no thread-safety check of any kind. A thread receives an opaque
pointer, and the types behind it are your claim, not the compiler's.

That leaves the two properties as rules you uphold by convention:

1. Moving a value to another thread is sound when nothing else can reach the
   value afterward, and when the value has no hidden link back to the
   original thread (for example, a cached pointer into thread-local state).
2. Sharing a value between threads is sound when every concurrent access is a
   read, or when every write goes through atomics or a lock.

The rest of this section shows each rule in code, then a way to enforce a
rule at run time when a type needs it.

### Shared reads

Any number of threads may read one `List` at once as long as no thread writes
to it. The sample makes the read-only intent explicit by casting the shared
pointer to an immutable untracked origin. Each worker writes only its own
`Stripe`, so the writes stay disjoint.

```mojo
# Claims:
#   - Any number of threads may read the same List at once, as long as no
#     thread writes to it. Nothing in the type system states or checks this;
#     the program upholds it.
#   - Each worker writes only its own result slot, so the writes are
#     disjoint and need no synchronization before the join.
from threads import ThreadArg, erase, spawn, join
from std.testing import assert_equal

comptime WORKERS = 4


struct Stripe(Movable):
    var readings: Pointer[List[Int], ImmUntrackedOrigin]
    var first: Int
    var stride: Int
    var total: Int

    def __init__(out self, readings: Pointer[List[Int], ImmUntrackedOrigin], first: Int):
        self.readings = readings
        self.first = first
        self.stride = WORKERS
        self.total = 0


def sum_stripe(arg: ThreadArg) abi("C") -> ThreadArg:
    var stripe = arg.unsafe_bitcast[Stripe]()
    ref readings = stripe[].readings[]
    var position = stripe[].first
    while position < len(readings):
        stripe[].total += readings[position]
        position += stripe[].stride
    return arg


def main() raises:
    var latencies_ms = List[Int](capacity=1000)
    for index in range(1000):
        latencies_ms.append(index % 97)
    var shared = Pointer(to=latencies_ms).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()

    var stripes = List[Stripe](capacity=WORKERS)
    for worker in range(WORKERS):
        stripes.append(Stripe(shared, worker))
    var handles = List[Int]()
    for worker in range(WORKERS):
        handles.append(spawn(sum_stripe, erase(stripes[worker])))
    for handle in handles:
        join(handle)

    var expected = 0
    for latency in latencies_ms:
        expected += latency
    var combined = 0
    for worker in range(WORKERS):
        combined += stripes[worker].total
    assert_equal(combined, expected)
```

[code/08-concurrency/shared_read_only_list.mojo](code/08-concurrency/shared_read_only_list.mojo)

Two smaller lessons hide in this sample. `List` iteration requires `Copyable`
elements, so the final loop indexes `stripes` instead of iterating it. And
the immutable cast is documentation, not enforcement: nothing stops another
thread from casting back.

### Handing off ownership

Moving a value to another thread means placing it in memory both threads can
address, then letting exactly one side own it. The worker takes the value out
with `unsafe_take_pointee()`, which leaves the slot uninitialized, and the
value's destruction then happens on the worker's thread.

```mojo
# Claims:
#   - Handing a value to another thread means moving it into memory that
#     both threads can address, then letting exactly one side destroy it.
#   - The receiving thread takes the value out with unsafe_take_pointee(),
#     becomes its sole owner, and its destruction happens on that thread.
#   - The sender must not touch the moved-out slot again until the join.
#   - Assertions run after `dealloc`: a raising call while the linear
#     Allocation is live would leave it unconsumed on the error path, and
#     the compiler rejects that.
from threads import ThreadArg, spawn, join
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


struct Batch(Movable):
    var orders: List[Int]
    var checksum: Int

    def __init__(out self, var orders: List[Int]):
        self.orders = orders^
        self.checksum = 0


def process_batch(arg: ThreadArg) abi("C") -> ThreadArg:
    var slot = arg.unsafe_bitcast[Batch]()
    var batch = slot.unsafe_take_pointee()  # this thread owns the batch now
    var checksum = 0
    for order_id in batch.orders:
        checksum += order_id
    # Leave the result where the sender can find it. The orders List dies
    # here, on this thread, when `batch` reaches its last use.
    slot.unsafe_write(Batch(List[Int]()))
    slot[].checksum = checksum
    return arg


def main() raises:
    var storage = alloc(Layout[Batch].single())
    var slot = storage.unsafe_ptr()
    slot.unsafe_write(Batch([10452, 10453, 10457, 10460]))

    var erased = slot.unsafe_origin_cast[MutUntrackedOrigin]().unsafe_bitcast[NoneType]()
    join(spawn(process_batch, erased))

    var checksum = slot[].checksum
    var orders_left = len(slot[].orders)
    slot.unsafe_deinit_pointee()
    dealloc(storage^)
    assert_equal(checksum, 41822)
    assert_equal(orders_left, 0)
```

[code/08-concurrency/hand_off_ownership.mojo](code/08-concurrency/hand_off_ownership.mojo)

Notice where the assertions sit. `Allocation` is a linear type, and a raising
call while it is live would abandon it on the error path. The compiler
rejects that, so the sample copies out what it wants to check, frees the
storage, and asserts last.

### Thread-safe counts, unsynchronized values

`ArcPointer` is the standard library's shared-ownership pointer. Its
reference count uses atomics, so copies may live on different threads. Its
subscript, however, hands out a mutable reference through any copy, even one
bound immutably. The count is thread-safe; the value behind it is yours to
protect.

```mojo
# Claims:
#   - ArcPointer copies share one heap value, and `arc[]` returns a mutable
#     reference through any copy, even a copy held by an immutable binding.
#   - So ArcPointer makes the reference count thread-safe, not the value:
#     guarding the value against concurrent writes is the program's job.
#   - A copy dies at its last use: after apply_discount() the count drops
#     back to 1 even though `pricing_view` is still in scope.
from std.memory import ArcPointer
from std.testing import assert_equal


def apply_discount(prices: ArcPointer[List[Int]]):
    # `prices` is a read-only argument, yet the subscript hands out a
    # mutable reference to the shared list.
    for ref price in prices[]:
        price -= price // 10


def main() raises:
    var prices: List[Int] = [1200, 450, 990]
    var catalog = ArcPointer(prices^)
    var pricing_view = catalog.copy()
    assert_equal(catalog.count(), 2)
    apply_discount(pricing_view)  # last use of `pricing_view`
    assert_equal(catalog.count(), 1)
    assert_equal(catalog[], [1080, 405, 891])
```

[code/08-concurrency/arc_subscript_is_mutable.mojo](code/08-concurrency/arc_subscript_is_mutable.mojo)

`ArcPointer.ptr()` is the conservative accessor. It always returns an
immutable pointer, whatever the mutability of the `ArcPointer` itself:

```mojo
# EXPECT-ERROR: ArcPointer.ptr() returns an immutable pointer, so writing through it fails
# EXPECT-MATCH: (immutable|not mutable|cannot be mutated|must be mutable)
# Claims:
#   - ArcPointer.ptr() always returns an immutable pointer, regardless of
#     how the ArcPointer itself is bound, to discourage shared mutation.
from std.memory import ArcPointer


def main():
    var inventory = ArcPointer(320)
    var view = inventory.ptr()
    view[] = 319
```

[code/08-concurrency/arc_ptr_is_immutable_fails.mojo](code/08-concurrency/arc_ptr_is_immutable_fails.mojo)

The count drop in the first sample is ASAP destruction again: `pricing_view`
dies after its last use, inside the scope that declared it.

### Enforcing confinement at run time

When a type must stay on the thread that created it, the type can check that
rule itself. `pthread_self()` identifies the calling thread, and
`pthread_equal()` compares two thread IDs. (POSIX makes no promise that `==`
on a `pthread_t` means anything.)

```mojo
# Claims:
#   - The type system has no notion of "this value must stay on one thread".
#     A type that needs that rule can enforce it at run time instead.
#   - pthread_self() identifies the calling thread; pthread_equal() compares
#     two thread IDs (POSIX does not promise that `==` on them is meaningful).
#   - Use from the owning thread passes the check.
from threads import ThreadArg
from std.ffi import external_call, c_int
from std.os import abort
from std.testing import assert_equal


def current_thread() -> Int:
    return external_call["pthread_self", Int]()


struct FrameRecorder(Movable):
    """Records draw calls. Its buffers are not synchronized, so only the
    thread that created it may use it."""
    var owner: Int
    var draw_calls: Int

    def __init__(out self):
        self.owner = current_thread()
        self.draw_calls = 0

    def record_draw(mut self):
        if external_call["pthread_equal", c_int](self.owner, current_thread()) == 0:
            abort("FrameRecorder used off its owning thread")
        self.draw_calls += 1


def main() raises:
    var recorder = FrameRecorder()
    for _ in range(3):
        recorder.record_draw()
    assert_equal(recorder.draw_calls, 3)
```

[code/08-concurrency/thread_confined_guard.mojo](code/08-concurrency/thread_confined_guard.mojo)

The same type, touched from a worker thread, aborts the process:

```mojo
def draw_from_worker(arg: ThreadArg) abi("C") -> ThreadArg:
    arg.unsafe_bitcast[FrameRecorder]()[].record_draw()
    return arg


def main():
    var recorder = FrameRecorder()
    join(spawn(draw_from_worker, erase(recorder)))
    print(recorder.draw_calls)
```

[code/08-concurrency/thread_confined_guard_aborts.mojo](code/08-concurrency/thread_confined_guard_aborts.mojo) (excerpt)

A run-time guard costs one comparison per call and catches the mistake the
first time it happens, not the hundredth time a race shows up.

## 8.3 Atomics

*Rustonomicon counterpart: 8.3, Atomics.*

`std.atomic` provides three things: `Atomic[T]`, a value that only atomic
operations touch; `Ordering`, which says how an atomic operation orders the
plain memory accesses around it; and `fence()`, an ordering with no memory
access attached.

### The orderings

`Ordering` defines seven values. Five matter for CPU code:

- `RELAXED`: the operation itself is atomic, and it orders nothing else.
  Right for counters whose value nobody uses to decide what other memory to
  read.
- `RELEASE` (stores and read-modify-writes): every memory access this thread
  made before the operation becomes visible to a thread that acquires the
  value it wrote.
- `ACQUIRE` (loads and read-modify-writes): once this thread observes a
  released value, it sees everything the releasing thread wrote before it.
- `ACQUIRE_RELEASE`: both, for a read-modify-write.
- `SEQUENTIAL`: acquire and release, plus a single total order of all
  sequentially consistent operations across all threads.

`NOT_ATOMIC` and `UNORDERED` exist for compiler-level use and do not belong in
synchronization code.

Defaults vary by operation and by target. `load()` and `store()` default to
`SEQUENTIAL` everywhere. The arithmetic and compare-exchange operations take
their default from the compilation target's plugin: `SEQUENTIAL` on CPU
targets, and `RELAXED` under the Metal plugin for Apple GPUs. Code that must
behave the same on every target spells out its orderings.

### Atomic is a place, not a value

`Atomic` has no copy. A copy would be a second, unrelated counter:

```mojo
# EXPECT-ERROR: Atomic has no copy; a copy would be a second, unrelated counter
# EXPECT-MATCH: no attribute 'copy'
# Claims:
#   - Atomic is not Copyable. It is still Movable, so the program must not
#     move one while another thread holds its address.
from std.atomic import Atomic


def main():
    var connections = Atomic[Int64](0)
    var snapshot = connections.copy()
```

[code/08-concurrency/atomic_not_copyable_fails.mojo](code/08-concurrency/atomic_not_copyable_fails.mojo)

It is still `Movable`, because every Mojo struct is unless it opts out. Moving
an `Atomic` changes its address, so a program must never move one while
another thread holds a pointer to it. Chapter 10 builds its shared block as a
`not Movable` struct for exactly this reason.

Every operation that writes takes `mut self`. A read-only argument permits
`load()` and nothing else:

```mojo
# EXPECT-ERROR: atomic read-modify-write needs mutable access to the Atomic
# EXPECT-MATCH: must be mutable
# Claims:
#   - fetch_add, +=, store, and compare_exchange take `mut self`. Holding an
#     Atomic through a read-only argument only permits load().
from std.atomic import Atomic


def record_hit(hits: Atomic[Int64]):
    hits += 1


def main():
    var hits = Atomic[Int64](0)
    record_hit(hits)
```

[code/08-concurrency/atomic_requires_mut_fails.mojo](code/08-concurrency/atomic_requires_mut_fails.mojo)

### compare_exchange

`compare_exchange(expected, desired)` stores `desired` only when the current
value equals `expected`, and reports whether it did. On failure it writes the
value it actually found into `expected`, which is why that argument is `mut`.

```mojo
# Claims:
#   - compare_exchange(expected, desired) stores `desired` only when the
#     current value equals `expected`, and returns whether it did.
#   - On failure it writes the value it actually saw back into `expected`,
#     which is why `expected` is a `mut` argument and why CAS loops never
#     need a separate reload.
from std.atomic import Atomic
from std.testing import assert_equal, assert_false, assert_true


def main() raises:
    var config_version = Atomic[UInt64](7)

    var expected = UInt64(7)
    assert_true(config_version.compare_exchange(expected, 8))
    assert_equal(config_version.load(), 8)

    expected = 7  # stale: another writer already moved it to 8
    assert_false(config_version.compare_exchange(expected, 9))
    assert_equal(expected, 8)  # refreshed with the value it observed
    assert_equal(config_version.load(), 8)  # unchanged
```

[code/08-concurrency/compare_exchange_semantics.mojo](code/08-concurrency/compare_exchange_semantics.mojo)

That refresh-on-failure behavior makes compare-exchange loops short: there is
no separate reload. Any read-modify-write operation can be built this way.
This sample builds an atomic maximum and checks it against the built-in
`Atomic.max()`. It also passes `weak=True`, which allows the exchange to fail
even when the values match. A spurious failure costs one more pass of a retry
loop, and on some architectures the weak form compiles to a tighter
instruction sequence; outside a loop it is a bug.

```mojo
# Claims:
#   - Any read-modify-write operation can be built from a compare_exchange
#     loop. Here: an atomic maximum.
#   - A weak compare_exchange may fail spuriously, so it belongs only
#     inside a retry loop, where a spurious failure costs one more pass.
#   - The hand-built loop and Atomic.max() agree across 8 threads.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering
from std.testing import assert_equal


struct QueueStats(Movable):
    var deepest_by_loop: Atomic[Int64]
    var deepest_by_max: Atomic[Int64]
    var next_thread: Atomic[Int64]

    def __init__(out self):
        self.deepest_by_loop = Atomic[Int64](0)
        self.deepest_by_max = Atomic[Int64](0)
        self.next_thread = Atomic[Int64](0)


def raise_to(mut mark: Atomic[Int64], depth: Int64):
    var observed = mark.load[ordering=Ordering.RELAXED]()
    while observed < depth:
        if mark.compare_exchange[
            success_ordering=Ordering.RELAXED,
            failure_ordering=Ordering.RELAXED,
            weak=True,
        ](observed, depth):
            return


def sample_queue_depths(arg: ThreadArg) abi("C") -> ThreadArg:
    var stats = arg.unsafe_bitcast[QueueStats]()
    var thread_number = Int(stats[].next_thread.fetch_add(1))
    for step in range(1000):
        var depth = Int64((step * 37 + thread_number * 101) % 4096)
        raise_to(stats[].deepest_by_loop, depth)
        stats[].deepest_by_max.max(depth)
    return arg


def main() raises:
    var stats = QueueStats()
    run_threads(sample_queue_depths, erase(stats), 8)
    assert_equal(stats.deepest_by_loop.load(), 4095)
    assert_equal(stats.deepest_by_max.load(), stats.deepest_by_loop.load())
```

[code/08-concurrency/cas_loop_high_water_mark.mojo](code/08-concurrency/cas_loop_high_water_mark.mojo)

### Release and acquire carry plain data

Orderings exist so that atomics can publish memory that is not atomic. The
producer writes two plain fields, then stores a flag with `RELEASE`. The
consumer spins until an `ACQUIRE` load sees the flag, and from that point the
plain fields hold the producer's values.

```mojo
# Claims:
#   - A RELEASE store to a flag publishes every write the thread made
#     before it. An ACQUIRE load that sees the flag sees all of them.
#   - With that pairing, the payload itself needs no atomics: the consumer
#     reads plain fields and always finds the producer's values.
from threads import ThreadArg, erase, spawn, join
from std.atomic import Atomic, Ordering
from std.testing import assert_equal


struct Mailbox(Movable):
    var ready: Atomic[UInt8]
    var sequence: Int
    var payload_bytes: Int
    var observed_sequence: Int
    var observed_bytes: Int

    def __init__(out self):
        self.ready = Atomic[UInt8](0)
        self.sequence = 0
        self.payload_bytes = 0
        self.observed_sequence = 0
        self.observed_bytes = 0


def produce(arg: ThreadArg) abi("C") -> ThreadArg:
    var mailbox = arg.unsafe_bitcast[Mailbox]()
    mailbox[].sequence = 1729          # plain writes...
    mailbox[].payload_bytes = 65536
    mailbox[].ready.store[ordering=Ordering.RELEASE](1)  # ...published here
    return arg


def consume(arg: ThreadArg) abi("C") -> ThreadArg:
    var mailbox = arg.unsafe_bitcast[Mailbox]()
    while mailbox[].ready.load[ordering=Ordering.ACQUIRE]() == 0:
        pass
    mailbox[].observed_sequence = mailbox[].sequence  # plain reads, now safe
    mailbox[].observed_bytes = mailbox[].payload_bytes
    return arg


def main() raises:
    var mailbox = Mailbox()
    var consumer = spawn(consume, erase(mailbox))
    var producer = spawn(produce, erase(mailbox))
    join(producer)
    join(consumer)
    assert_equal(mailbox.observed_sequence, 1729)
    assert_equal(mailbox.observed_bytes, 65536)
```

[code/08-concurrency/release_acquire_handoff.mojo](code/08-concurrency/release_acquire_handoff.mojo)

`fence()` moves the ordering off the atomic operation. A `RELEASE` fence
followed by a `RELAXED` store publishes like a `RELEASE` store, and a
`RELAXED` load followed by an `ACQUIRE` fence acquires like an `ACQUIRE` load.
The consumer pays for ordering once, after it stops polling, instead of on
every poll.

```mojo
# Claims:
#   - fence() moves the ordering off the atomic operation: a RELEASE fence
#     followed by a RELAXED store publishes like a RELEASE store, and a
#     RELAXED load followed by an ACQUIRE fence acquires like an ACQUIRE load.
#   - The pattern pays for the fence once, after a loop of relaxed polls,
#     instead of on every poll.
from threads import ThreadArg, erase, spawn, join
from std.atomic import Atomic, Ordering, fence
from std.testing import assert_equal


struct Handoff(Movable):
    var ready: Atomic[UInt8]
    var frame_count: Int
    var seen_frames: Int

    def __init__(out self):
        self.ready = Atomic[UInt8](0)
        self.frame_count = 0
        self.seen_frames = 0


def render(arg: ThreadArg) abi("C") -> ThreadArg:
    var handoff = arg.unsafe_bitcast[Handoff]()
    handoff[].frame_count = 240
    fence[ordering=Ordering.RELEASE]()
    handoff[].ready.store[ordering=Ordering.RELAXED](1)
    return arg


def present(arg: ThreadArg) abi("C") -> ThreadArg:
    var handoff = arg.unsafe_bitcast[Handoff]()
    while handoff[].ready.load[ordering=Ordering.RELAXED]() == 0:
        pass
    fence[ordering=Ordering.ACQUIRE]()
    handoff[].seen_frames = handoff[].frame_count
    return arg


def main() raises:
    var handoff = Handoff()
    var presenter = spawn(present, erase(handoff))
    var renderer = spawn(render, erase(handoff))
    join(renderer)
    join(presenter)
    assert_equal(handoff.seen_frames, 240)
```

[code/08-concurrency/fence_handoff.mojo](code/08-concurrency/fence_handoff.mojo)

### Atomic operations on plain memory

The `Atomic` methods also exist as static functions that take a pointer.
They let a plain heap buffer of `Int64` take atomic updates without wrapping
each element. The rule that comes with them: once any thread accesses an
element atomically, every concurrent access to that element must be atomic
too. Plain reads wait for the join.

```mojo
# Claims:
#   - Atomic's static methods operate on any suitably typed pointer, so a
#     plain heap buffer of Int64 can take atomic updates without wrapping
#     each element in an Atomic.
#   - Every concurrent access to those elements must go through the atomic
#     methods. Plain reads happen only after the join.
#   - `histogram` has no later use, so without the deinit() call its life
#     would end at erase() while the threads still read it.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal

comptime BUCKETS = 16


struct Histogram(Movable):
    var counts: Pointer[Int64, MutUntrackedOrigin]

    def __init__(out self, counts: Pointer[Int64, MutUntrackedOrigin]):
        self.counts = counts


def record_latencies(arg: ThreadArg) abi("C") -> ThreadArg:
    var counts = arg.unsafe_bitcast[Histogram]()[].counts
    for sample in range(4800):
        var bucket = counts.unsafe_offset(sample % BUCKETS)
        _ = Atomic[Int64].fetch_add[ordering=Ordering.RELAXED](bucket, 1)
    return arg


def main() raises:
    var storage = alloc(Layout[Int64](length=BUCKETS))
    var counts = storage.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    for bucket in range(BUCKETS):
        counts.unsafe_offset(bucket).write(0)

    var histogram = Histogram(counts)
    run_threads(record_latencies, erase(histogram), 6)
    deinit(histogram^)  # keeps `histogram` alive until every thread has joined

    var total = Int64(0)
    var bucket_zero = counts[]
    for bucket in range(BUCKETS):
        total += counts[unsafe_offset=bucket]
    dealloc(storage^)
    assert_equal(bucket_zero, 6 * 4800 // BUCKETS)
    assert_equal(total, 6 * 4800)
```

[code/08-concurrency/atomic_view_of_plain_memory.mojo](code/08-concurrency/atomic_view_of_plain_memory.mojo)

### Worked example: the ArcPointer reference count

The standard library's `ArcPointer` uses three different orderings for three
different jobs. Its source is the clearest statement of the rules above.

Incrementing needs no ordering. The thread that copies already holds a live
reference, so the count cannot reach zero during the increment, and no other
memory depends on the new count:

```mojo
# From std/memory/arc_pointer.mojo (excerpt)
def add_strong(mut self):
    _ = self.strong.fetch_add[ordering=Ordering.RELAXED](1)
```

Decrementing uses `RELEASE`, so that each owner's writes to the payload
happen before its decrement. Only the owner that takes the count to zero
needs to see all of those writes, so it alone pays for an `ACQUIRE` fence
before it destroys the payload:

```mojo
# From std/memory/arc_pointer.mojo (excerpt)
def drop_strong(mut self) -> Bool:
    if self.strong.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
        return False
    fence[ordering=Ordering.ACQUIRE]()
    return True
```

Upgrading a weak pointer must never revive a payload that already died, so
it increments only from a non-zero count, in a compare-exchange loop that
acquires on success:

```mojo
# From std/memory/arc_pointer.mojo (excerpt)
def try_add_strong(mut self) -> Bool:
    var cur = self.strong.load[ordering=Ordering.RELAXED]()
    while cur != 0:
        if self.strong.compare_exchange[
            success_ordering=Ordering.ACQUIRE,
            failure_ordering=Ordering.RELAXED,
        ](cur, cur + 1):
            return True
    return False
```

The release-then-fence pattern stands on its own, without a smart pointer
around it. Eight threads each fill a slot with plain writes and then
decrement a shared owner count. Exactly one thread takes the count to zero,
and after its fence it sees all eight slots filled.

```mojo
# Claims:
#   - The reference-count release pattern: every owner decrements with
#     RELEASE; the owner that takes the count from 1 to 0 issues an ACQUIRE
#     fence before touching the shared data.
#   - That pairing guarantees the last owner sees every write any other
#     owner made before its own decrement, so exactly one thread finds all
#     8 slots filled.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering, fence
from std.testing import assert_equal

comptime OWNERS = 8


struct SharedReport(Movable):
    var owners: Atomic[UInt64]
    var next_slot: Atomic[Int64]
    var shard_totals: List[Int]
    var final_total: Int
    var cleanups: Atomic[Int64]

    def __init__(out self):
        self.owners = Atomic[UInt64](OWNERS)
        self.next_slot = Atomic[Int64](0)
        self.shard_totals = List[Int](length=OWNERS, fill=0)
        self.final_total = 0
        self.cleanups = Atomic[Int64](0)


def finish_shard(arg: ThreadArg) abi("C") -> ThreadArg:
    var report = arg.unsafe_bitcast[SharedReport]()
    var slot = Int(report[].next_slot.fetch_add(1))
    report[].shard_totals[slot] = (slot + 1) * 1000  # plain write

    if report[].owners.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
        return arg  # not the last owner
    fence[ordering=Ordering.ACQUIRE]()
    var total = 0
    for index in range(OWNERS):
        total += report[].shard_totals[index]
    report[].final_total = total
    report[].cleanups += 1
    return arg


def main() raises:
    var report = SharedReport()
    run_threads(finish_shard, erase(report), OWNERS)
    assert_equal(report.cleanups.load(), 1)
    assert_equal(report.final_total, 36000)
```

[code/08-concurrency/last_owner_cleans_up.mojo](code/08-concurrency/last_owner_cleans_up.mojo)

Chapter 10 builds a complete reference-counted pointer around this pattern.
