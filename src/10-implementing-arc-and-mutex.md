# 10. Implementing Arc and Mutex

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/memory/arc_pointer.mojo, Mojo/stdlib/std/memory/alloc.mojo, Mojo/stdlib/std/memory/maybe_uninit.mojo, Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/atomic/atomic.mojo, Mojo/stdlib/std/utils/lock.mojo, Mojo/stdlib/std/traits/deinitable.mojo, Mojo/stdlib/std/traits/anytype.mojo, Mojo/stdlib/std/utils/_nicheable.mojo -->

This chapter builds `SharedBox[T]`, an atomically reference-counted heap box that mirrors the standard library's `ArcPointer`, from `alloc`, `Atomic`, and `MaybeUninit`. It then builds `SpinMutex[T]`, a lock that owns its data and whose guard keeps the lock held for exactly as long as you use it.

## 10.1 Arc

*Rustonomicon counterpart: 10.1, Arc.*

The threaded samples in this chapter start threads through the same POSIX
helper module as chapter 8, and every ordering choice comes from section 8.3.

A `SharedBox[T]` is a pointer to one heap block. The block holds a strong
count and the payload. Copying the box increments the count; destroying a
copy decrements it; the copy that takes the count to zero destroys the
payload and frees the block.

### 10.1.1 Layout

*Rustonomicon counterpart: 10.1.1, Layout.*

The block is its own struct:

```mojo
struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]
```

Each choice carries a reason.

- `not Movable`. Every copy of the box holds the block's address, and the
  `Atomic` inside it is a place other threads point at. A move would change
  that address. Opting out of `Movable` makes the compiler refuse any move of
  the block.
- `MaybeUninit[T]` for the payload. The last owner destroys the payload before
  it frees the block, so for a moment the block exists with no live payload
  in it. `MaybeUninit` is storage the compiler makes no claims about, which is
  exactly what that moment needs. It is also the hook for weak references:
  with a second count, the block outlives the payload by design.
- The box itself holds one `Pointer[SharedInner[T], MutUntrackedOrigin]`. The
  block came from the allocator and aliases no Mojo-owned value, so an
  untracked origin is the honest one.

The sizes follow from that, including one quiet difference from the standard
library:

```mojo
# Claims:
#   - A SharedBox is one pointer wide; the count and payload live on the heap.
#   - MaybeUninit[T] has exactly the size of T: it adds no flag.
#   - The heap block is count plus payload, padded to the larger alignment:
#     a one-byte payload still occupies 16 bytes.
#   - Optional[Pointer] reuses the null address as None, so it stays 8 bytes.
#     A struct that wraps a Pointer does not inherit that niche: Optional of
#     this SharedBox needs 16 bytes, while the stdlib ArcPointer opts into
#     the niche through a non-public conformance and stays at 8.
from std.atomic import Atomic
from std.memory import ArcPointer, MaybeUninit
from std.sys import align_of, size_of
from std.testing import assert_equal


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Movable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]


def main() raises:
    assert_equal(size_of[SharedBox[String]](), size_of[Int]())
    assert_equal(size_of[MaybeUninit[String]](), size_of[String]())
    assert_equal(size_of[SharedInner[Int64]](), 16)
    assert_equal(size_of[SharedInner[UInt8]](), 16)
    assert_equal(align_of[SharedInner[UInt8]](), 8)

    assert_equal(size_of[Optional[Pointer[Int, MutUntrackedOrigin]]](), 8)
    assert_equal(size_of[Optional[SharedBox[String]]](), 16)
    assert_equal(size_of[Optional[ArcPointer[String]]](), 8)
```

[code/10-implementing-arc-and-mutex/shared_layout_sizes.mojo](code/10-implementing-arc-and-mutex/shared_layout_sizes.mojo)

`Optional[ArcPointer[String]]` fits in 8 bytes because `ArcPointer` declares
that its null address can never occur and lends that bit pattern to
`Optional` as its `None`. That conformance is not public, so a struct you
write that wraps a `Pointer` pays 8 extra bytes inside an `Optional`.

`MaybeUninit[String]` is not `Deinitable`: it never knows whether it holds a
live `String`, and it refuses to guess. A struct is `Deinitable` by default,
and a compiler-generated deinitializer cannot destroy that field, so the
compiler rejects the declaration:

```mojo
# EXPECT-ERROR: a MaybeUninit field of a non-trivial payload must be released explicitly
# EXPECT-MATCH: non-.Deinitable
# Claims:
#   - MaybeUninit[String] is not Deinitable: it never knows whether it holds
#     a live String, so it refuses to guess.
#   - A struct is Deinitable by default, and a compiler-generated
#     deinitializer cannot destroy that field, so the declaration itself is
#     rejected. Writing a __deinit__ that consumes the field (for example
#     with unsafe_forget()) settles the question.
from std.atomic import Atomic
from std.memory import MaybeUninit


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()


def main():
    var block = SharedInner[String]()
    _ = block.strong.load()
```

[code/10-implementing-arc-and-mutex/inner_without_deinit_fails.mojo](code/10-implementing-arc-and-mutex/inner_without_deinit_fails.mojo)

The fix is a `__deinit__` that settles the question. `SharedInner` consumes
the field with `unsafe_forget()`, because by the time the block dies the last
owner has already destroyed the payload:

```mojo
def __deinit__(deinit self):
    self.payload^.unsafe_forget()
```

### 10.1.2 Base code

*Rustonomicon counterpart: 10.1.2, Base Code.*

Constructing the block takes two phases. A non-`Movable` value cannot be
built on the stack and moved into the heap, so `unsafe_write(init_with=...)`
builds it in place from a closure. That closure cannot take ownership of a
payload that is only `Movable`:

```mojo
# EXPECT-ERROR: an init_with closure cannot capture a move-only payload by value
# EXPECT-MATCH: cannot capture value by copy
# Claims:
#   - Building a non-Movable block in place needs unsafe_write(init_with=...).
#   - That closure cannot take ownership of a payload that is only Movable,
#     which is why SharedBox builds the block first and writes the payload
#     into its MaybeUninit field second.
from std.atomic import Atomic
from std.memory import alloc, Layout, MaybeUninit


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self, var value: Self.T):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T](value^)

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


def make_block[T: Movable](var value: T) -> Pointer[SharedInner[T], MutUntrackedOrigin]:
    var block = alloc(Layout[SharedInner[T]].single()).unsafe_leak()
    block.unsafe_write(init_with=lambda () {var value} -> SharedInner[T]: SharedInner[T](value^))
    return block


def main():
    _ = make_block(String("route table"))
```

[code/10-implementing-arc-and-mutex/capture_move_only_fails.mojo](code/10-implementing-arc-and-mutex/capture_move_only_fails.mojo)

So the constructor builds the block with an uninitialized payload, then moves
the payload into the `MaybeUninit` field:

```mojo
def __init__(out self, var value: Self.T):
    var block = alloc(Layout[SharedInner[Self.T]].single()).unsafe_leak()
    block.unsafe_write(
        init_with=lambda () -> SharedInner[Self.T]: SharedInner[Self.T]()
    )
    block[].payload.unsafe_write(value^)
    self.inner = block
```

`alloc()` returns a linear `Allocation` that the compiler forces you to
consume. `unsafe_leak()` consumes it and hands back the raw pointer. From that
line on, nothing tracks the allocation except code you write, which is the
point: the count decides when the block dies, not the scope.

The base version has a single owner. Its deinitializer runs the teardown in
the order every later version keeps: payload, then block, then storage.

```mojo
# Base code: one owner, no copies yet.
# Claims:
#   - The box allocates its block with alloc(...).unsafe_leak(): from here
#     on, nothing tracks the allocation except the box's own deinitializer.
#   - The block is written in two phases: the non-Movable SharedInner is
#     built in place, then the payload moves into its MaybeUninit field.
#   - Destroying the box destroys the payload, then the block, then frees
#     the storage, in that order.
from std.atomic import Atomic, Ordering
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.testing import assert_equal


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Movable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, var value: Self.T):
        var block = alloc(Layout[SharedInner[Self.T]].single()).unsafe_leak()
        block.unsafe_write(
            init_with=lambda () -> SharedInner[Self.T]: SharedInner[Self.T]()
        )
        block[].payload.unsafe_write(value^)
        self.inner = block

    def __deinit__(deinit self):
        self.inner[].payload.unsafe_ptr().unsafe_deinit_pointee()
        self.inner.unsafe_deinit_pointee()
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.inner).unsafe_with_layout(
                Layout[SharedInner[Self.T]].single()
            )
        )

    def __getitem__[
        self_origin: ImmOrigin
    ](ref[self_origin] self) -> ref[self_origin.unsafe_mut_cast[True]()] Self.T:
        return (
            self.inner[]
            .payload.unsafe_ptr()
            .unsafe_origin_cast[self_origin.unsafe_mut_cast[True]()]()[]
        )

    def count(self) -> UInt64:
        return self.inner[].strong.load[ordering=Ordering.RELAXED]()


def main() raises:
    var routes: List[String] = ["10.0.0.0/8", "172.16.0.0/12"]
    var table = SharedBox(routes^)
    table[].append("192.168.0.0/16")
    assert_equal(len(table[]), 3)
    assert_equal(table.count(), 1)
```

[code/10-implementing-arc-and-mutex/shared_box_base.mojo](code/10-implementing-arc-and-mutex/shared_box_base.mojo)

The subscript returns a mutable reference, as `ArcPointer`'s does. The
`self_origin` parameter lets the result borrow from whichever binding holds
the box, and `unsafe_mut_cast[True]()` widens it to mutable. That cast is the
design decision behind this whole type: shared ownership, unshared
responsibility for writes. Section 10.2 supplies the discipline.

### 10.1.3 Cloning

*Rustonomicon counterpart: 10.1.3, Cloning.*

Cloning increments the count and shares the pointer. No allocation, no copy
of the payload.

```mojo
def __init__(out self, *, copy: Self):
    var previous = copy.inner[].strong.fetch_add[ordering=Ordering.RELAXED](1)
    if previous > MAX_REFCOUNT:
        abort("SharedBox reference count overflow")
    self.inner = copy.inner
```

`RELAXED` is enough, for the reason section 8.3 gave for `ArcPointer`: the
copying thread already holds a live reference, so the count cannot reach zero
while the increment is in flight, and nothing else in memory depends on the
new value.

The overflow check guards against a program that leaks copies (with
`forget_deinit()`, for example) until the count wraps. A wrapped count would
free a block that live copies still point at, so the box aborts instead.
`MAX_REFCOUNT` sits at half the `UInt64` range, which leaves headroom for many
threads to overshoot before any of them sees the check.

Copies share one payload, and each copy dies at its last use rather than at
the end of its scope. Watch the count fall in the middle of the function:

```mojo
# Cloning.
# Claims:
#   - The copy constructor bumps the count with a RELAXED fetch_add and
#     shares the pointer. No allocation, no payload copy.
#   - Copies see each other's writes because they share one payload.
#   - Copies die at their last use (ASAP), not at the end of the scope, so
#     the count falls as soon as a copy is no longer needed.
from std.atomic import Atomic, Ordering
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.os import abort
from std.testing import assert_equal

comptime MAX_REFCOUNT = UInt64(Int64.MAX)


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Copyable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, var value: Self.T):
        var block = alloc(Layout[SharedInner[Self.T]].single()).unsafe_leak()
        block.unsafe_write(
            init_with=lambda () -> SharedInner[Self.T]: SharedInner[Self.T]()
        )
        block[].payload.unsafe_write(value^)
        self.inner = block

    def __init__(out self, *, copy: Self):
        var previous = copy.inner[].strong.fetch_add[ordering=Ordering.RELAXED](1)
        if previous > MAX_REFCOUNT:
            abort("SharedBox reference count overflow")
        self.inner = copy.inner

    def __deinit__(deinit self):
        # Not yet thread-safe: section 10.1.4 adds the orderings.
        if self.inner[].strong.fetch_sub(1) != 1:
            return
        self.inner[].payload.unsafe_ptr().unsafe_deinit_pointee()
        self.inner.unsafe_deinit_pointee()
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.inner).unsafe_with_layout(
                Layout[SharedInner[Self.T]].single()
            )
        )

    def __getitem__[
        self_origin: ImmOrigin
    ](ref[self_origin] self) -> ref[self_origin.unsafe_mut_cast[True]()] Self.T:
        return (
            self.inner[]
            .payload.unsafe_ptr()
            .unsafe_origin_cast[self_origin.unsafe_mut_cast[True]()]()[]
        )

    def count(self) -> UInt64:
        return self.inner[].strong.load[ordering=Ordering.RELAXED]()


def main() raises:
    var session_ids: List[Int] = [4471, 4472]
    var sessions = SharedBox(session_ids^)
    var audit_view = sessions.copy()
    var cache_view = sessions.copy()
    assert_equal(sessions.count(), 3)

    cache_view[].append(4480)  # last use of `cache_view`
    assert_equal(sessions.count(), 2)
    assert_equal(len(audit_view[]), 3)  # last use of `audit_view`
    assert_equal(sessions.count(), 1)
```

[code/10-implementing-arc-and-mutex/shared_box_clone.mojo](code/10-implementing-arc-and-mutex/shared_box_clone.mojo)

`SharedBox` conforms to `Copyable`, not `ImplicitlyCopyable`, so every count
increment is a visible `.copy()`. The standard library's `ArcPointer` makes
the other choice and copies implicitly. Either is sound; the explicit form
puts every reference-count increment in plain sight when you profile.

```mojo
# EXPECT-ERROR: SharedBox is Copyable but not ImplicitlyCopyable, so a plain assignment cannot copy it
# EXPECT-MATCH: implicitly cop
# Claims:
#   - SharedBox conforms to Copyable only. Every refcount increment is a
#     visible .copy() call; `var second = first` while `first` stays in use
#     does not compile. (The stdlib ArcPointer chooses ImplicitlyCopyable.)
from std.atomic import Atomic
from std.memory import MaybeUninit


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Copyable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]):
        self.inner = inner

    def __init__(out self, *, copy: Self):
        _ = copy.inner[].strong.fetch_add(1)
        self.inner = copy.inner


def share(first: SharedBox[Int]):
    var second = first
    _ = second.inner
    _ = first.inner


def main():
    pass
```

[code/10-implementing-arc-and-mutex/implicit_copy_fails.mojo](code/10-implementing-arc-and-mutex/implicit_copy_fails.mojo)

### 10.1.4 Dropping

*Rustonomicon counterpart: 10.1.4, Dropping.*

The deinitializer decrements, and the owner that takes the count from 1 to 0
tears everything down:

```mojo
def __deinit__(deinit self):
    if self.inner[].strong.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
        return
    fence[ordering=Ordering.ACQUIRE]()
    self.inner[].payload.unsafe_ptr().unsafe_deinit_pointee()
    self.inner.unsafe_deinit_pointee()
    dealloc(
        ThinAllocation(unsafe_owned_ptr=self.inner).unsafe_with_layout(
            Layout[SharedInner[Self.T]].single()
        )
    )
```

The orderings answer one question: when the last owner destroys the payload,
has every other owner finished with it? Each owner's `RELEASE` decrement
publishes everything that owner did to the payload. The last owner's
`ACQUIRE` fence synchronizes with all of those decrements, so its
destruction happens after every other owner's last access. Without the fence,
the payload's deinitializer could run while another thread's final write to
the payload is still in flight.

The three teardown steps each do one job:

1. `unsafe_deinit_pointee()` on the payload pointer runs the payload's
   deinitializer and leaves the `MaybeUninit` storage uninitialized.
2. `unsafe_deinit_pointee()` on the block runs `SharedInner.__deinit__`, which
   forgets the now-empty payload storage.
3. `dealloc()` releases the memory. `ThinAllocation` re-wraps the raw pointer
   and `unsafe_with_layout()` re-attaches the layout `alloc()` used, so the
   allocator gets back exactly what it handed out.

Whichever copy dies last does the work, and the payload's deinitializer runs
exactly once:

```mojo
# Dropping.
# Claims:
#   - The payload's deinitializer runs exactly once, when the last copy
#     dies, no matter which copy that is.
#   - The decrement uses RELEASE; the last owner adds an ACQUIRE fence
#     before it destroys the payload (section 10.1.4 explains why).
#   - The order of destruction is payload, then block, then storage.
from std.atomic import Atomic, Ordering, fence
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.testing import assert_equal


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Copyable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, var value: Self.T):
        var block = alloc(Layout[SharedInner[Self.T]].single()).unsafe_leak()
        block.unsafe_write(
            init_with=lambda () -> SharedInner[Self.T]: SharedInner[Self.T]()
        )
        block[].payload.unsafe_write(value^)
        self.inner = block

    def __init__(out self, *, copy: Self):
        _ = copy.inner[].strong.fetch_add[ordering=Ordering.RELAXED](1)
        self.inner = copy.inner

    def __deinit__(deinit self):
        if self.inner[].strong.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
            return
        fence[ordering=Ordering.ACQUIRE]()
        self.inner[].payload.unsafe_ptr().unsafe_deinit_pointee()
        self.inner.unsafe_deinit_pointee()
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.inner).unsafe_with_layout(
                Layout[SharedInner[Self.T]].single()
            )
        )


struct Connection(Movable):
    var host: String
    var log: Pointer[List[String], MutUntrackedOrigin]

    def __init__(out self, host: String, log: Pointer[List[String], MutUntrackedOrigin]):
        self.host = host
        self.log = log

    def __deinit__(deinit self):
        self.log[].append(String("closed ", self.host))


def main() raises:
    var log = List[String]()
    var log_ptr = Pointer(to=log).unsafe_origin_cast[MutUntrackedOrigin]()

    var primary = SharedBox(Connection("db.internal:5432", log_ptr))
    var replica = primary.copy()
    var reporter = replica.copy()

    log.append("primary released")
    deinit(primary^)
    log.append("reporter released")
    deinit(reporter^)
    log.append("replica released")
    deinit(replica^)  # the last owner closes the connection
    assert_equal(
        log,
        [
            "primary released",
            "reporter released",
            "replica released",
            "closed db.internal:5432",
        ],
    )
```

[code/10-implementing-arc-and-mutex/shared_box_drop_once.mojo](code/10-implementing-arc-and-mutex/shared_box_drop_once.mojo)

### 10.1.5 Final code

*Rustonomicon counterpart: 10.1.5, Final Code.*

The complete type, with a test that churns copies from eight threads at once.
Each thread makes and drops 10,000 copies. A lost increment would let the
count reach zero while copies still point at the block, and a lost decrement
would leave it above 1 forever; either way the final count would not be 1.

```mojo
# The final SharedBox: an atomically reference-counted heap box.
# Claims:
#   - Copies share one heap block; count() reports the live copies.
#   - Clone increments with RELAXED; drop decrements with RELEASE, and the
#     last owner issues an ACQUIRE fence before destroying the payload.
#   - The payload's deinitializer runs exactly once, on the last drop, and
#     the block is freed right after it.
#   - Copies and drops from 8 threads at once leave the count exact.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering, fence
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.os import abort
from std.testing import assert_equal

comptime MAX_REFCOUNT = UInt64(Int64.MAX)


struct SharedInner[T: Movable](not Movable):
    """The heap block every copy points at. It never moves once written."""
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        # The last SharedBox destroys the payload before it destroys the
        # block, so only the (uninitialized) storage is left to discard.
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Copyable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, var value: Self.T):
        var block = alloc(Layout[SharedInner[Self.T]].single()).unsafe_leak()
        block.unsafe_write(
            init_with=lambda () -> SharedInner[Self.T]: SharedInner[Self.T]()
        )
        block[].payload.unsafe_write(value^)
        self.inner = block

    def __init__(out self, *, copy: Self):
        # RELAXED is enough: the caller already holds a live copy, so the
        # count cannot reach zero while this increment is in flight.
        var previous = copy.inner[].strong.fetch_add[ordering=Ordering.RELAXED](1)
        if previous > MAX_REFCOUNT:
            abort("SharedBox reference count overflow")
        self.inner = copy.inner

    def __deinit__(deinit self):
        if self.inner[].strong.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
            return
        # Pairs with every other owner's RELEASE decrement: their writes to
        # the payload happen before the destruction below.
        fence[ordering=Ordering.ACQUIRE]()
        self.inner[].payload.unsafe_ptr().unsafe_deinit_pointee()
        self.inner.unsafe_deinit_pointee()
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.inner).unsafe_with_layout(
                Layout[SharedInner[Self.T]].single()
            )
        )

    def __getitem__[
        self_origin: ImmOrigin
    ](ref[self_origin] self) -> ref[self_origin.unsafe_mut_cast[True]()] Self.T:
        """Returns a mutable reference to the shared value. Synchronizing
        writes through it is the caller's job."""
        return (
            self.inner[]
            .payload.unsafe_ptr()
            .unsafe_origin_cast[self_origin.unsafe_mut_cast[True]()]()[]
        )

    def count(self) -> UInt64:
        return self.inner[].strong.load[ordering=Ordering.RELAXED]()


struct DropLog(Movable):
    """A payload that records its own destruction in a log owned by main()."""
    var label: String
    var log: Pointer[List[String], MutUntrackedOrigin]

    def __init__(out self, label: String, log: Pointer[List[String], MutUntrackedOrigin]):
        self.label = label
        self.log = log

    def __deinit__(deinit self):
        self.log[].append(String(self.label, " destroyed"))


def churn_copies(arg: ThreadArg) abi("C") -> ThreadArg:
    ref shared = arg.unsafe_bitcast[SharedBox[DropLog]]()[]
    for _ in range(10_000):
        var local = shared.copy()  # +1 here, -1 at its last use
        _ = local.count()
    return arg


def main() raises:
    var log = List[String]()
    var log_ptr = Pointer(to=log).unsafe_origin_cast[MutUntrackedOrigin]()

    var config = SharedBox(DropLog("config", log_ptr))
    var reader = config.copy()
    assert_equal(config.count(), 2)
    assert_equal(reader[].label, "config")  # last use of `reader`
    assert_equal(config.count(), 1)

    run_threads(churn_copies, erase(config), 8)
    assert_equal(config.count(), 1)
    assert_equal(len(log), 0)  # payload still alive

    deinit(config^)  # last owner: destroys the payload, frees the block
    assert_equal(log, ["config destroyed"])
```

[code/10-implementing-arc-and-mutex/shared_box.mojo](code/10-implementing-arc-and-mutex/shared_box.mojo)

### What the standard library adds

`ArcPointer` follows the same design and adds two features.

Weak references. A second atomic count tracks `WeakPointer`s. All strong
pointers together hold one implicit weak reference, so the block survives the
payload until the last weak pointer is gone. `try_upgrade()` succeeds while
the payload lives and returns `None` afterward:

```mojo
# Claims:
#   - The stdlib ArcPointer adds weak references on top of the design in
#     this chapter: a second count, and a block that outlives the payload.
#   - A weak pointer does not keep the payload alive. try_upgrade() returns
#     a new strong pointer while one exists, and None after the last strong
#     pointer dies, even though the weak pointer itself is still live.
#   - weak_count() excludes the one implicit weak reference that all strong
#     pointers share.
from std.memory import ArcPointer
from std.testing import assert_equal, assert_false


def main() raises:
    var device_names: List[String] = ["gpu0", "gpu1"]
    var registry = ArcPointer(device_names^)
    var watcher = ArcPointer[List[String]].WeakPointer(downgrade=registry)
    assert_equal(registry.count(), 1)
    assert_equal(registry.weak_count(), 1)

    var upgraded = watcher.try_upgrade()
    assert_equal(upgraded.value().count(), 2)  # last use of `upgraded`
    assert_equal(registry.count(), 1)

    deinit(registry^)  # the payload dies here
    assert_equal(watcher.strong_count(), 0)
    assert_false(Bool(watcher.try_upgrade()))
```

[code/10-implementing-arc-and-mutex/std_arc_pointer_weak.mojo](code/10-implementing-arc-and-mutex/std_arc_pointer_weak.mojo)

Linear payloads. `ArcPointer` accepts a payload that is not `Deinitable`. Each
owner must then end its life with `deinit_with()`, passing the payload's named
destructor, and only the last owner calls it:

```mojo
# Claims:
#   - ArcPointer can hold a non-Deinitable payload. Each owner must then be
#     consumed with deinit_with(), and only the last one actually invokes
#     the named destructor.
#   - While a non-Deinitable owner is live, a raising call is rejected: the
#     error path would abandon it. So this sample records what it observes
#     and asserts only after both owners are consumed.
from std.memory import ArcPointer
from std.testing import assert_equal


struct LeaseToken(Movable, not Deinitable):
    """Callers must give it back explicitly; dropping it silently is a compile error."""
    var lease_id: Int
    var returned: Pointer[List[Int], MutUntrackedOrigin]

    def __init__(out self, lease_id: Int, returned: Pointer[List[Int], MutUntrackedOrigin]):
        self.lease_id = lease_id
        self.returned = returned

    def give_back(deinit self):
        self.returned[].append(self.lease_id)


def main() raises:
    var returned = List[Int]()
    var returned_ptr = Pointer(to=returned).unsafe_origin_cast[MutUntrackedOrigin]()
    var lease = ArcPointer(LeaseToken(8812, returned_ptr))
    var holder = lease.copy()
    lease^.deinit_with(LeaseToken.give_back)
    var returned_while_held = len(returned)  # `holder` still owns a reference
    holder^.deinit_with(LeaseToken.give_back)
    assert_equal(returned_while_held, 0)
    assert_equal(returned, [8812])
```

[code/10-implementing-arc-and-mutex/std_arc_deinit_with.mojo](code/10-implementing-arc-and-mutex/std_arc_deinit_with.mojo)

That sample records what it observes and asserts only after both owners are
consumed. While a non-`Deinitable` owner is live, a raising call would
abandon it on the error path, and the compiler rejects the program.

## 10.2 Mutex

*Rustonomicon counterpart: the Rustonomicon's chapter title promises a
Mutex; this section supplies it.*

A mutex in this chapter owns the data it protects, and the only way to that
data is through a guard. The guard's existence is the lock: creating it
acquires, destroying it releases.

### The spin mutex

`lock()` spins until a compare-exchange flips the flag from 0 to 1 with
`ACQUIRE`. The guard's deinitializer stores 0 with `RELEASE`. That pair makes
every write one holder made visible to the next holder, so the protected
value itself needs no atomics. Between attempts, waiting threads poll with
`RELAXED` loads, which read a shared cache line instead of fighting for
exclusive ownership of it.

```mojo
# The final SpinMutex.
# Claims:
#   - lock() spins until a compare_exchange flips the flag from 0 to 1 with
#     ACQUIRE; the guard's deinitializer stores 0 with RELEASE. Everything
#     one holder wrote is visible to the next holder.
#   - Between attempts, the loop polls with plain RELAXED loads, so waiting
#     threads read a shared cache line instead of fighting over it.
#   - The guard's reference is tied to the guard, so the lock stays held
#     while that reference is in use.
#   - 8 threads x 10,000 locked increments of a plain Int total exactly 80,000.
#   - try_lock() fails while a guard is live and succeeds after it dies.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering
from std.testing import assert_equal, assert_true


struct SpinMutex[T: Movable & Deinitable](Movable):
    var locked: Atomic[UInt8]
    var value: Self.T

    def __init__(out self, var value: Self.T):
        self.locked = Atomic[UInt8](0)
        self.value = value^

    def lock(mut self) -> MutexGuard[Self.T, origin_of(self)]:
        while True:
            var expected = UInt8(0)
            if self.locked.compare_exchange[
                success_ordering=Ordering.ACQUIRE,
                failure_ordering=Ordering.RELAXED,
                weak=True,
            ](expected, 1):
                return MutexGuard[Self.T, origin_of(self)](self)
            while self.locked.load[ordering=Ordering.RELAXED]() != 0:
                pass

    def try_lock(mut self) -> Optional[MutexGuard[Self.T, origin_of(self)]]:
        var expected = UInt8(0)
        if self.locked.compare_exchange[
            success_ordering=Ordering.ACQUIRE,
            failure_ordering=Ordering.RELAXED,
        ](expected, 1):
            return MutexGuard[Self.T, origin_of(self)](self)
        return None


struct MutexGuard[T: Movable & Deinitable, origin: MutOrigin](Movable):
    var mutex: Pointer[SpinMutex[Self.T], Self.origin]

    def __init__(out self, ref[Self.origin] mutex: SpinMutex[Self.T]):
        self.mutex = Pointer(to=mutex)

    def __getitem__(mut self) -> ref[self] Self.T:
        # Tie the returned reference to the guard, not to the mutex: the
        # guard stays alive, and the lock stays held, while it is in use.
        return Pointer(to=self.mutex[].value).unsafe_origin_cast[origin_of(self)]()[]

    def __deinit__(deinit self):
        self.mutex[].locked.store[ordering=Ordering.RELEASE](0)


def add_shipments(arg: ThreadArg) abi("C") -> ThreadArg:
    var mutex = arg.unsafe_bitcast[SpinMutex[Int]]()
    for _ in range(10_000):
        var guard = mutex[].lock()
        guard[] += 1  # last use of `guard`: unlocks right after this line
    return arg


def main() raises:
    var shipped = SpinMutex(0)
    run_threads(add_shipments, erase(shipped), 8)
    assert_equal(shipped.value, 80_000)

    var held = shipped.lock()
    var blocked = shipped.try_lock()
    var blocked_while_held = not Bool(blocked)
    held[] += 1  # last use of `held`: unlocks here
    var free_again = Bool(shipped.try_lock())
    assert_true(blocked_while_held)
    assert_true(free_again)
    assert_equal(shipped.value, 80_001)
```

[code/10-implementing-arc-and-mutex/spin_mutex.mojo](code/10-implementing-arc-and-mutex/spin_mutex.mojo)

`guard[] += 1` is the last use of the guard, so the guard dies and unlocks
right after that line. ASAP destruction gives you the shortest critical
section by default.

### Tie the reference to the guard

The guard's subscript signature is the most important line in the type:

```mojo
def __getitem__(mut self) -> ref[self] Self.T:
    return Pointer(to=self.mutex[].value).unsafe_origin_cast[origin_of(self)]()[]
```

The returned reference carries the guard's origin, so while you use the
reference, the guard stays alive and the lock stays held:

```mojo
# Claims:
#   - When the guard's subscript returns a reference tied to the guard
#     (`ref[self]`), the guard lives as long as that reference is used, so
#     the lock flag reads 1 the whole time.
#   - After the reference's last use, the guard dies and the flag reads 0.
from std.atomic import Atomic, Ordering
from std.testing import assert_equal


struct SpinMutex[T: Movable & Deinitable](Movable):
    var locked: Atomic[UInt8]
    var value: Self.T

    def __init__(out self, var value: Self.T):
        self.locked = Atomic[UInt8](0)
        self.value = value^

    def lock(mut self) -> MutexGuard[Self.T, origin_of(self)]:
        while True:
            var expected = UInt8(0)
            if self.locked.compare_exchange[
                success_ordering=Ordering.ACQUIRE,
                failure_ordering=Ordering.RELAXED,
                weak=True,
            ](expected, 1):
                return MutexGuard[Self.T, origin_of(self)](self)
            while self.locked.load[ordering=Ordering.RELAXED]() != 0:
                pass

    def try_lock(mut self) -> Optional[MutexGuard[Self.T, origin_of(self)]]:
        var expected = UInt8(0)
        if self.locked.compare_exchange[
            success_ordering=Ordering.ACQUIRE,
            failure_ordering=Ordering.RELAXED,
        ](expected, 1):
            return MutexGuard[Self.T, origin_of(self)](self)
        return None


struct MutexGuard[T: Movable & Deinitable, origin: MutOrigin](Movable):
    var mutex: Pointer[SpinMutex[Self.T], Self.origin]

    def __init__(out self, ref[Self.origin] mutex: SpinMutex[Self.T]):
        self.mutex = Pointer(to=mutex)

    def __getitem__(mut self) -> ref[self] Self.T:
        # Tie the returned reference to the guard, not to the mutex: the
        # guard stays alive, and the lock stays held, while it is in use.
        return Pointer(to=self.mutex[].value).unsafe_origin_cast[origin_of(self)]()[]

    def __deinit__(deinit self):
        self.mutex[].locked.store[ordering=Ordering.RELEASE](0)
def main() raises:
    var inventory = SpinMutex(250)
    var lock_flag = Pointer(to=inventory.locked).unsafe_origin_cast[MutUntrackedOrigin]()
    var guard = inventory.lock()
    ref stock = guard[]
    var flag_while_in_use = lock_flag[].load()
    stock -= 40  # last use of `stock`, and so of `guard`
    var flag_after = lock_flag[].load()
    assert_equal(flag_while_in_use, 1)
    assert_equal(flag_after, 0)
    assert_equal(inventory.value, 210)
```

[code/10-implementing-arc-and-mutex/guard_ref_tied_keeps_lock.mojo](code/10-implementing-arc-and-mutex/guard_ref_tied_keeps_lock.mojo)

Return a reference with the mutex's origin instead, and the guard no longer
has any reason to live past the subscript call. It dies there, and unlocks,
while the caller still holds a reference into the protected value. In a
single thread that shows up only as a flag reading 0. With threads it is a
data race.

```mojo
# Claims:
#   - If the guard's subscript returns a reference with the MUTEX's origin,
#     the reference no longer keeps the guard alive. The guard dies at its
#     own last use (the subscript call) and unlocks while the caller still
#     holds the reference.
#   - In one thread that only shows up as a flag reading 0. With threads it
#     is a data race, which is why the final MutexGuard ties the reference
#     to itself.
from std.atomic import Atomic, Ordering
from std.testing import assert_equal


struct SpinMutex[T: Movable & Deinitable](Movable):
    var locked: Atomic[UInt8]
    var value: Self.T

    def __init__(out self, var value: Self.T):
        self.locked = Atomic[UInt8](0)
        self.value = value^

    def lock(mut self) -> LooseGuard[Self.T, origin_of(self)]:
        var expected = UInt8(0)
        while not self.locked.compare_exchange[
            success_ordering=Ordering.ACQUIRE,
            failure_ordering=Ordering.RELAXED,
            weak=True,
        ](expected, 1):
            expected = 0
        return LooseGuard[Self.T, origin_of(self)](self)


struct LooseGuard[T: Movable & Deinitable, origin: MutOrigin](Movable):
    var mutex: Pointer[SpinMutex[Self.T], Self.origin]

    def __init__(out self, ref[Self.origin] mutex: SpinMutex[Self.T]):
        self.mutex = Pointer(to=mutex)

    def __getitem__(ref self) -> ref[Self.origin] Self.T:
        # The reference outlives nothing it should: its origin is the mutex.
        return Pointer(to=self.mutex[].value).unsafe_origin_cast[Self.origin]()[]

    def __deinit__(deinit self):
        self.mutex[].locked.store[ordering=Ordering.RELEASE](0)


def main() raises:
    var inventory = SpinMutex(250)
    var lock_flag = Pointer(to=inventory.locked).unsafe_origin_cast[MutUntrackedOrigin]()
    var guard = inventory.lock()
    ref stock = guard[]  # last use of `guard`: it unlocks right here
    var flag_while_in_use = lock_flag[].load()
    stock -= 40
    assert_equal(flag_while_in_use, 0)  # unlocked too early
    assert_equal(inventory.value, 210)
```

[code/10-implementing-arc-and-mutex/guard_ref_untied_unlocks_early.mojo](code/10-implementing-arc-and-mutex/guard_ref_untied_unlocks_early.mojo)

Neither version compiles if you return `self.mutex[].value` directly: the
compiler tracks field origins precisely and rejects a reference to the
`value` field under any other origin. The explicit `unsafe_origin_cast` is
where you state which lifetime the reference really has, and getting it wrong
is the bug above.

The guard also pins the mutex. Its pointer carries the mutex's origin, so
every use of the guard counts as a use of the mutex, and moving the mutex out
from under a live guard fails:

```mojo
# EXPECT-ERROR: using the guard after moving the mutex counts as using the moved-out mutex
# EXPECT-MATCH: (cannot be consumed|uninitialized value 'inventory')
# Claims:
#   - The guard holds a Pointer whose origin is the mutex, so every use of
#     the guard is a use of the mutex. Moving the mutex out from under a
#     live guard makes the later guard use a use of a moved-out value, and
#     the compiler rejects it.
from std.atomic import Atomic, Ordering


struct SpinMutex[T: Movable & Deinitable](Movable):
    var locked: Atomic[UInt8]
    var value: Self.T

    def __init__(out self, var value: Self.T):
        self.locked = Atomic[UInt8](0)
        self.value = value^

    def lock(mut self) -> MutexGuard[Self.T, origin_of(self)]:
        while True:
            var expected = UInt8(0)
            if self.locked.compare_exchange[
                success_ordering=Ordering.ACQUIRE,
                failure_ordering=Ordering.RELAXED,
                weak=True,
            ](expected, 1):
                return MutexGuard[Self.T, origin_of(self)](self)
            while self.locked.load[ordering=Ordering.RELAXED]() != 0:
                pass

    def try_lock(mut self) -> Optional[MutexGuard[Self.T, origin_of(self)]]:
        var expected = UInt8(0)
        if self.locked.compare_exchange[
            success_ordering=Ordering.ACQUIRE,
            failure_ordering=Ordering.RELAXED,
        ](expected, 1):
            return MutexGuard[Self.T, origin_of(self)](self)
        return None


struct MutexGuard[T: Movable & Deinitable, origin: MutOrigin](Movable):
    var mutex: Pointer[SpinMutex[Self.T], Self.origin]

    def __init__(out self, ref[Self.origin] mutex: SpinMutex[Self.T]):
        self.mutex = Pointer(to=mutex)

    def __getitem__(mut self) -> ref[self] Self.T:
        # Tie the returned reference to the guard, not to the mutex: the
        # guard stays alive, and the lock stays held, while it is in use.
        return Pointer(to=self.mutex[].value).unsafe_origin_cast[origin_of(self)]()[]

    def __deinit__(deinit self):
        self.mutex[].locked.store[ordering=Ordering.RELEASE](0)
def main():
    var inventory = SpinMutex(250)
    var guard = inventory.lock()
    var relocated = inventory^
    guard[] -= 40
    _ = relocated.value
```

[code/10-implementing-arc-and-mutex/move_mutex_while_locked_fails.mojo](code/10-implementing-arc-and-mutex/move_mutex_while_locked_fails.mojo)

### Sharing a mutex through a SharedBox

The two types compose. Each worker receives its own `SharedBox` copy, moved
into a slot that the worker takes ownership of, so each copy dies on its
worker's thread and the decrements race with other workers' work. The
mutex inside serializes the writes.

```mojo
# SharedBox and SpinMutex together.
# Claims:
#   - Each thread receives its own SharedBox copy, moved into a slot it
#     takes ownership of. The copy dies on the worker thread, so
#     decrements happen concurrently with other threads' work.
#   - The mutex inside the box serializes the writes: the tally is exact.
#   - After every worker finishes, main holds the only remaining reference.
from threads import ThreadArg, spawn, join
from std.atomic import Atomic, Ordering, fence
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.os import abort
from std.testing import assert_equal

comptime WORKERS = 8


comptime MAX_REFCOUNT = UInt64(Int64.MAX)


struct SharedInner[T: Movable](not Movable):
    """The heap block every copy points at. It never moves once written."""
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        # The last SharedBox destroys the payload before it destroys the
        # block, so only the (uninitialized) storage is left to discard.
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Copyable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, var value: Self.T):
        var block = alloc(Layout[SharedInner[Self.T]].single()).unsafe_leak()
        block.unsafe_write(
            init_with=lambda () -> SharedInner[Self.T]: SharedInner[Self.T]()
        )
        block[].payload.unsafe_write(value^)
        self.inner = block

    def __init__(out self, *, copy: Self):
        # RELAXED is enough: the caller already holds a live copy, so the
        # count cannot reach zero while this increment is in flight.
        var previous = copy.inner[].strong.fetch_add[ordering=Ordering.RELAXED](1)
        if previous > MAX_REFCOUNT:
            abort("SharedBox reference count overflow")
        self.inner = copy.inner

    def __deinit__(deinit self):
        if self.inner[].strong.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
            return
        # Pairs with every other owner's RELEASE decrement: their writes to
        # the payload happen before the destruction below.
        fence[ordering=Ordering.ACQUIRE]()
        self.inner[].payload.unsafe_ptr().unsafe_deinit_pointee()
        self.inner.unsafe_deinit_pointee()
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.inner).unsafe_with_layout(
                Layout[SharedInner[Self.T]].single()
            )
        )

    def __getitem__[
        self_origin: ImmOrigin
    ](ref[self_origin] self) -> ref[self_origin.unsafe_mut_cast[True]()] Self.T:
        """Returns a mutable reference to the shared value. Synchronizing
        writes through it is the caller's job."""
        return (
            self.inner[]
            .payload.unsafe_ptr()
            .unsafe_origin_cast[self_origin.unsafe_mut_cast[True]()]()[]
        )

    def count(self) -> UInt64:
        return self.inner[].strong.load[ordering=Ordering.RELAXED]()
struct SpinMutex[T: Movable & Deinitable](Movable):
    var locked: Atomic[UInt8]
    var value: Self.T

    def __init__(out self, var value: Self.T):
        self.locked = Atomic[UInt8](0)
        self.value = value^

    def lock(mut self) -> MutexGuard[Self.T, origin_of(self)]:
        while True:
            var expected = UInt8(0)
            if self.locked.compare_exchange[
                success_ordering=Ordering.ACQUIRE,
                failure_ordering=Ordering.RELAXED,
                weak=True,
            ](expected, 1):
                return MutexGuard[Self.T, origin_of(self)](self)
            while self.locked.load[ordering=Ordering.RELAXED]() != 0:
                pass

    def try_lock(mut self) -> Optional[MutexGuard[Self.T, origin_of(self)]]:
        var expected = UInt8(0)
        if self.locked.compare_exchange[
            success_ordering=Ordering.ACQUIRE,
            failure_ordering=Ordering.RELAXED,
        ](expected, 1):
            return MutexGuard[Self.T, origin_of(self)](self)
        return None


struct MutexGuard[T: Movable & Deinitable, origin: MutOrigin](Movable):
    var mutex: Pointer[SpinMutex[Self.T], Self.origin]

    def __init__(out self, ref[Self.origin] mutex: SpinMutex[Self.T]):
        self.mutex = Pointer(to=mutex)

    def __getitem__(mut self) -> ref[self] Self.T:
        # Tie the returned reference to the guard, not to the mutex: the
        # guard stays alive, and the lock stays held, while it is in use.
        return Pointer(to=self.mutex[].value).unsafe_origin_cast[origin_of(self)]()[]

    def __deinit__(deinit self):
        self.mutex[].locked.store[ordering=Ordering.RELEASE](0)
def tally_votes(arg: ThreadArg) abi("C") -> ThreadArg:
    var slot = arg.unsafe_bitcast[SharedBox[SpinMutex[Int]]]()
    var tally = slot.unsafe_take_pointee()  # this thread owns its copy now
    for _ in range(2_500):
        var guard = tally[].lock()
        guard[] += 1
    return arg  # `tally` died at its last use above, on this thread


def main() raises:
    var tally = SharedBox(SpinMutex(0))
    var slots = alloc(Layout[SharedBox[SpinMutex[Int]]](length=WORKERS))
    var base = slots.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    for worker in range(WORKERS):
        base.unsafe_offset(worker).unsafe_write(tally.copy())
    var peak_count = tally.count()

    var handles = List[Int]()
    for worker in range(WORKERS):
        handles.append(spawn(tally_votes, base.unsafe_offset(worker).unsafe_bitcast[NoneType]()))
    for handle in handles:
        join(handle)
    dealloc(slots^)  # every worker moved its slot out; only the storage remains

    assert_equal(peak_count, WORKERS + 1)
    assert_equal(tally.count(), 1)
    assert_equal(tally[].value, WORKERS * 2_500)
```

[code/10-implementing-arc-and-mutex/shared_mutex_counter.mojo](code/10-implementing-arc-and-mutex/shared_mutex_counter.mojo)

### The standard library's spin lock

`std.utils.lock` ships a different design. `BlockingSpinLock` owns no data:
it is an atomic flag, and the program decides which memory it protects.
`BlockingScopedLock` locks in `__enter__` and unlocks in `__exit__`, so a
`with` block is the critical section.

```mojo
# Claims:
#   - The stdlib's BlockingSpinLock guards no data of its own: it is a bare
#     flag, and the program decides which memory it protects.
#   - BlockingScopedLock locks in __enter__ and unlocks in __exit__, so a
#     `with` block is the critical section.
#   - 8 threads x 5,000 increments of a plain Int under the lock total 40,000.
from threads import ThreadArg, erase, run_threads
from std.utils.lock import BlockingScopedLock, BlockingSpinLock
from std.testing import assert_equal


struct Ledger(Movable):
    var lock: BlockingSpinLock
    var entries: Int

    def __init__(out self):
        self.lock = BlockingSpinLock()
        self.entries = 0


def post_entries(arg: ThreadArg) abi("C") -> ThreadArg:
    var ledger = arg.unsafe_bitcast[Ledger]()
    for _ in range(5_000):
        with BlockingScopedLock(ledger[].lock):
            ledger[].entries += 1
    return arg


def main() raises:
    var ledger = Ledger()
    run_threads(post_entries, erase(ledger), 8)
    assert_equal(ledger.entries, 40_000)
```

[code/10-implementing-arc-and-mutex/std_blocking_scoped_lock.mojo](code/10-implementing-arc-and-mutex/std_blocking_scoped_lock.mojo)

`BlockingSpinLock` stores an owner token instead of a plain flag, and
`unlock()` refuses any other token. `BlockingScopedLock` uses its own address
as the token. The check catches a mismatched unlock; it proves nothing about
threads, since any code that passes the right integer can unlock.

```mojo
# Claims:
#   - BlockingSpinLock records an owner token (BlockingScopedLock uses its
#     own address). unlock() with any other token returns False and leaves
#     the lock held.
#   - The check is a convention about tokens, not a proof about threads:
#     any code that passes the right integer can unlock.
from std.utils.lock import BlockingSpinLock
from std.testing import assert_equal, assert_false, assert_true


def main() raises:
    var lock = BlockingSpinLock()
    comptime SCHEDULER_TOKEN = 4096
    comptime INTRUDER_TOKEN = 8192
    lock.lock(SCHEDULER_TOKEN)
    assert_false(lock.unlock(INTRUDER_TOKEN))
    assert_equal(lock.counter.load(), Int64(SCHEDULER_TOKEN))
    assert_true(lock.unlock(SCHEDULER_TOKEN))
    assert_equal(lock.counter.load(), BlockingSpinLock.UNLOCKED)
```

[code/10-implementing-arc-and-mutex/std_spin_lock_owner_check.mojo](code/10-implementing-arc-and-mutex/std_spin_lock_owner_check.mojo)

Choose a data-owning mutex when the protected value has one obvious home: the
compiler then routes every access through the guard. Choose a bare lock when
the protected memory is scattered or foreign, and document which memory it
covers, because nothing else will.
