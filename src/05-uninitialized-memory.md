# 5. Uninitialized memory

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/memory/maybe_uninit.mojo, Mojo/stdlib/std/memory/memory.mojo, Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/memory/alloc.mojo, Mojo/stdlib/std/collections/span.mojo, Mojo/stdlib/std/collections/array.mojo, Mojo/stdlib/std/traits/deinitable.mojo -->

How Mojo tracks initialization at compile time, where it decides to destroy values, and how to work with memory the compiler can't see into.

Every binding in a Mojo function is in one of two states at every point in
the program: initialized or uninitialized. The compiler computes that state
for each binding, and for each field of a struct binding, along every
control-flow path. It uses the result twice: to reject reads of
uninitialized storage, and to decide where to destroy values.

Heap memory and raw pointers sit outside that analysis. Once you hold a
`Pointer` to storage from `alloc()`, initialization state becomes your job,
and the `unsafe_` prefix on the API marks each place where you vouch for it.

Each code block below omits its file's header comment, which restates the
claims the file tests. Files whose names end in `_fails.mojo` don't compile,
on purpose.

## 5.1 Checked

*Rustonomicon counterpart: Checked uninitialized memory.*

A `var` declaration without a value creates a binding in the uninitialized
state. You may assign it later, on any path, as long as every path that
reaches a read has assigned it first. No default value ever fills the gap.

```mojo
from std.sys import argv
from std.testing import assert_equal


def main() raises:
    var interactive = len(argv()) > 0  # known only at run time
    var timeout_ms: Int
    if interactive:
        timeout_ms = 5000
    else:
        timeout_ms = 250
    assert_equal(timeout_ms, 5000)

    var mode: String
    mode = "streaming" if interactive else "batch"
    assert_equal(mode, "streaming")
```

[code/05-uninitialized-memory/definite_init_both_branches.mojo](code/05-uninitialized-memory/definite_init_both_branches.mojo)

When one path skips the assignment, the read fails to compile. The compiler
reports the binding as uninitialized at the read, not at the branch.

```mojo
from std.sys import argv


def main():
    var timeout_ms: Int
    if len(argv()) > 0:
        timeout_ms = 5000
    print(timeout_ms)
```

[code/05-uninitialized-memory/use_before_init_fails.mojo](code/05-uninitialized-memory/use_before_init_fails.mojo)

Transfer with `^` returns a binding to the uninitialized state. If one branch
transfers the value away, the binding is uninitialized at the point where the
branches merge, so later reads fail the same way.

```mojo
from std.sys import argv


def submit(var job: String):
    pass


def main():
    var job = String("nightly-backup")
    if len(argv()) > 0:
        submit(job^)
    print(job)
```

[code/05-uninitialized-memory/use_after_conditional_transfer_fails.mojo](code/05-uninitialized-memory/use_after_conditional_transfer_fails.mojo)

### Fields have their own state

The analysis tracks struct fields individually. You can transfer a single
field out of a local value, and the rest of the value stays put. The struct
as a whole is then incomplete, and the compiler holds you to fixing that:
put a value back before anything uses or destroys the whole.

```mojo
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


struct Link[origin: MutOrigin](Movable):
    var primary: Tracer[Self.origin]
    var backup: Tracer[Self.origin]

    def __init__(
        out self, ref[Self.origin] log: List[String], primary: String, backup: String
    ):
        self.primary = Tracer(primary, log)
        self.backup = Tracer(backup, log)


def retire(var tracer: Tracer):
    tracer.log[].append("retire " + tracer.label)


def main() raises:
    var events = List[String]()
    var link = Link(events, "eth0", "wlan0")
    retire(link.primary^)
    link.primary = Tracer("eth1", events)
    events.append("relinked " + link.primary.label)
    _ = link^
    assert_equal(
        events,
        ["drop eth0", "retire eth0", "relinked eth1", "drop eth1", "drop wlan0"],
    )
```

[code/05-uninitialized-memory/partial_move_reinit.mojo](code/05-uninitialized-memory/partial_move_reinit.mojo)

The log in that sample shows "drop eth0" before "retire eth0". Inside
`retire`, the last use of `tracer` is the evaluation of the `append`
arguments, and Mojo destroys values right after their last use. The
destructor runs before `append` does. The same ordering shows up throughout
this chapter.

If nothing replaces the missing field, the program doesn't compile. The
remaining value has a hole in it, and no destructor knows how to tear down a
value with a hole. This holds even for a struct with no custom `__deinit__`.

```mojo
@fieldwise_init
struct Link(Movable):
    var primary: String
    var backup: String


def retire(var name: String):
    pass


def main():
    var link = Link("eth0", "wlan0")
    retire(link.primary^)
```

[code/05-uninitialized-memory/partial_move_abandoned_fails.mojo](code/05-uninitialized-memory/partial_move_abandoned_fails.mojo)

A method that takes `deinit self` is the sanctioned way to take a value
apart. It ends the value's life, so it may transfer fields out freely, and
the type's `__deinit__` never runs for that value. Fields the method never
touches die at the start of the method, because their last use already
passed.

```mojo
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


struct Link[origin: MutOrigin](Movable):
    var primary: Tracer[Self.origin]
    var backup: Tracer[Self.origin]

    def __init__(
        out self, ref[Self.origin] log: List[String], primary: String, backup: String
    ):
        self.primary = Tracer(primary, log)
        self.backup = Tracer(backup, log)

    def __deinit__(deinit self):
        self.primary.log[].append("Link.__deinit__")

    def detach_primary(deinit self) -> Tracer[Self.origin]:
        self.primary.log[].append("detach")
        return self.primary^


def main() raises:
    var events = List[String]()
    var link = Link(events, "eth0", "wlan0")
    var kept = link^.detach_primary()
    events.append("kept " + kept.label)
    _ = kept^
    assert_equal(events, ["drop wlan0", "detach", "kept eth0", "drop eth0"])
```

[code/05-uninitialized-memory/deinit_method_moves_fields.mojo](code/05-uninitialized-memory/deinit_method_moves_fields.mojo)

`var self` gives a method ownership, but not permission to dismantle. The
method still has to destroy `self` whole when it finishes, so moving a field
out is the same hole as before.

```mojo
struct Recorder(Movable):
    var samples: List[Int]

    def __init__(out self):
        self.samples = []

    def finish(var self) -> List[Int]:
        return self.samples^


def main():
    var recorder = Recorder()
    print(len(recorder^.finish()))
```

[code/05-uninitialized-memory/var_self_cannot_move_field_fails.mojo](code/05-uninitialized-memory/var_self_cannot_move_field_fails.mojo)

### Initializers and `out` arguments

Inside `__init__`, `self` starts uninitialized, and each field becomes
initialized when you assign it. Reading a field you've already set is fine
before the rest are done.

```mojo
from std.testing import assert_equal


struct Endpoint(Movable):
    var host: String
    var url: String
    var port: Int

    def __init__(out self, host: String, port: Int):
        self.host = host
        self.url = "https://" + self.host  # host is initialized, so this reads fine
        self.port = port


def main() raises:
    var api = Endpoint("api.internal", 8443)
    assert_equal(api.url, "https://api.internal")
    assert_equal(api.port, 8443)
```

[code/05-uninitialized-memory/init_field_tracking.mojo](code/05-uninitialized-memory/init_field_tracking.mojo)

A method call is different: it receives all of `self`, so it waits until
every field holds a value.

```mojo
struct Endpoint(Movable):
    var host: String
    var port: Int

    def __init__(out self, host: String, port: Int):
        self.host = host
        self.log_target()
        self.port = port

    def log_target(self):
        print(self.host, self.port)


def main():
    _ = Endpoint("api.internal", 8443)
```

[code/05-uninitialized-memory/init_method_call_before_complete_fails.mojo](code/05-uninitialized-memory/init_method_call_before_complete_fails.mojo)

An `out` argument is a C-style out argument that the compiler checks. The
callee receives uninitialized storage and must initialize it on every path
that returns normally. The `out self` of `__init__` is the most common case.

```mojo
def parse_retries(text: String, out retries: Int):
    if text == "default":
        retries = 3


def main():
    print(parse_retries("default"))
```

[code/05-uninitialized-memory/out_argument_all_paths_fails.mojo](code/05-uninitialized-memory/out_argument_all_paths_fails.mojo)

The error path follows the same bookkeeping. If a function raises after
initializing its `out` argument, Mojo destroys that value before the error
reaches the caller. If an `__init__` raises halfway, Mojo destroys exactly the
fields it set, field by field, and never runs `__deinit__`, because no
complete value ever existed.

```mojo
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def open_session[
    origin: MutOrigin
](ref[origin] log: List[String], fail: Bool, out session: Tracer[origin]) raises:
    session = Tracer("session", log)
    if fail:
        raise Error("handshake refused")


struct Pipeline[origin: MutOrigin](Movable):
    var reader: Tracer[Self.origin]
    var writer: Tracer[Self.origin]

    def __init__(out self, ref[Self.origin] log: List[String]) raises:
        self.reader = Tracer("reader", log)
        raise Error("writer unavailable")

    def __deinit__(deinit self):
        self.reader.log[].append("Pipeline.__deinit__")


def main() raises:
    var events = List[String]()
    try:
        _ = open_session(events, True)
    except e:
        events.append(String(e))
    try:
        _ = Pipeline(events)
    except e:
        events.append(String(e))
    assert_equal(
        events,
        ["drop session", "handshake refused", "drop reader", "writer unavailable"],
    )
```

[code/05-uninitialized-memory/out_argument_raise_cleanup.mojo](code/05-uninitialized-memory/out_argument_raise_cleanup.mojo)

## 5.2 Drop flags

*Rustonomicon counterpart: Drop flags.*

A language that destroys values at the end of scope needs to know, at that
point, whether a conditionally moved value still lives there. One way to
answer is a hidden run-time flag per binding. Mojo doesn't need one. It
destroys each value immediately after its last use on each path (ASAP
destruction), so it places every destructor call on a specific path at
compile time. When paths merge, the compiler has already destroyed or
transferred the value on each of them.

In the sample below, one branch transfers `snapshot` away. On the other
branch, the condition was the last use of `snapshot`, so Mojo destroys it as
that branch begins, before either `append` call.

```mojo
from std.sys import argv
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def archive(var tracer: Tracer):
    var label = tracer.label
    tracer^.log[].append("archive " + label)


def main() raises:
    var events = List[String]()
    var offline = len(argv()) == 0  # false at run time
    var snapshot = Tracer("snapshot", events)
    if offline:
        archive(snapshot^)
    else:
        events.append("else entered")
        events.append("else finished")
    events.append("joined")
    assert_equal(
        events, ["drop snapshot", "else entered", "else finished", "joined"]
    )
```

[code/05-uninitialized-memory/conditional_transfer_static_drop.mojo](code/05-uninitialized-memory/conditional_transfer_static_drop.mojo)

Conditional initialization works the same way in reverse. A binding assigned
on one path and never read afterward dies on that path, right after the
assignment. The merge point never has to ask whether it holds anything.

```mojo
from std.sys import argv
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def main() raises:
    var events = List[String]()
    var warm_start = len(argv()) > 0  # true at run time
    var cache: Tracer[origin_of(events)]
    if warm_start:
        cache = Tracer("cache", events)
        events.append("cache branch")
    events.append("joined")
    assert_equal(events, ["drop cache", "cache branch", "joined"])
```

[code/05-uninitialized-memory/conditional_init_drop.mojo](code/05-uninitialized-memory/conditional_init_drop.mojo)

Reassignment can't destroy the old value, because ASAP destruction already
did. The old value's last read comes before the assignment, and its
destructor runs right after that read.

```mojo
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def main() raises:
    var events = List[String]()
    var config = Tracer("v1", events)
    events.append("loaded " + config.label)
    config = Tracer("v2", events)
    events.append("loaded " + config.label)
    _ = config^
    assert_equal(events, ["drop v1", "loaded v1", "loaded v2", "drop v2"])
```

[code/05-uninitialized-memory/reassignment_drops_old_value.mojo](code/05-uninitialized-memory/reassignment_drops_old_value.mojo)

### Loops

A loop body runs any number of times, so a transfer inside it has to make
sure no later iteration can reach the now-empty binding. A `break` after the
transfer does that. On the path where the loop finishes normally, the value
dies once the loop ends.

```mojo
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def ship(var tracer: Tracer):
    pass


def main() raises:
    var events = List[String]()
    var batch = Tracer("batch", events)
    var attempts = 0
    for attempt in range(3):
        attempts += 1
        if attempt == 7:  # never true in this run
            ship(batch^)
            break
    events.append("tried " + String(attempts))
    assert_equal(events, ["drop batch", "tried 3"])
```

[code/05-uninitialized-memory/transfer_in_loop_with_break.mojo](code/05-uninitialized-memory/transfer_in_loop_with_break.mojo)

Without the `break`, a second iteration could transfer the binding again,
and the compiler rejects the loop.

```mojo
def ship(var batch: List[Int]):
    pass


def main():
    var batch: List[Int] = [512, 1024]
    for attempt in range(3):
        if attempt == 1:
            ship(batch^)
```

[code/05-uninitialized-memory/transfer_in_loop_fails.mojo](code/05-uninitialized-memory/transfer_in_loop_fails.mojo)

### Choosing the moment

ASAP destruction picks the earliest legal moment. When a value guards
something, such as a lock token whose destructor releases a resource, the
earliest moment is often wrong. The builtin `deinit(value^)` keeps a value
alive up to that call and destroys it there. A live reference also counts as
a use, so a value lives until the last use of any reference to it.

```mojo
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def main() raises:
    var events = List[String]()
    var lock = Tracer("lock", events)
    var token = Tracer("token", events)
    events.append("critical section")
    deinit(lock^)
    ref current = token
    events.append("between")
    var label = current.label  # last use of the reference, so token dies here
    assert_equal(
        events, ["critical section", "drop lock", "between", "drop token"]
    )
    assert_equal(label, "token")
```

[code/05-uninitialized-memory/deinit_extends_lifetime.mojo](code/05-uninitialized-memory/deinit_extends_lifetime.mojo)

The rule applies inside destructors too. In `__deinit__`, `self` is an
owned value like any other, and each field dies at its own last use. A field
the body never touches dies before the body's first line runs, and a field
the body reads dies right after that read, not when the body ends. A value
that nobody uses dies right after construction, which is why the whole
sequence in the next sample happens before "after rig".

```mojo
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


struct Rig[origin: MutOrigin](Movable):
    var motor: Tracer[Self.origin]
    var sensor: Tracer[Self.origin]
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, ref[Self.origin] log: List[String]):
        self.motor = Tracer("motor", log)
        self.sensor = Tracer("sensor", log)
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("body start")
        self.log[].append("reading " + self.sensor.label)
        self.log[].append("body end")


def main() raises:
    var events = List[String]()
    _ = Rig(events)
    events.append("after rig")
    assert_equal(
        events,
        [
            "drop motor",
            "body start",
            "drop sensor",
            "reading sensor",
            "body end",
            "after rig",
        ],
    )
```

[code/05-uninitialized-memory/field_drops_inside_deinit.mojo](code/05-uninitialized-memory/field_drops_inside_deinit.mojo)

## 5.3 Unchecked

*Rustonomicon counterpart: Unchecked uninitialized memory.*

The compiler's analysis covers bindings and their fields. It stops at a
pointer. The storage behind a `Pointer` can hold any mix of initialized and
uninitialized elements, and nothing in the type records which. Mojo gives you
three tools for that territory:

- `Pointer` methods with an `unsafe_` prefix, which state the initialization
  state they expect and the one they leave behind.
- `MaybeUninit[T]`, a value-sized slot that the compiler treats as possibly
  uninitialized, so it never runs `T`'s destructor on its own.
- Bulk helpers on spans and in `std.memory` that move, copy, initialize, and
  destroy ranges.

### Writing, assigning, taking, and destroying through a pointer

`alloc()` returns storage with no values in it. Each pointer operation
assumes a state for the slot it touches:

| Operation | Slot before | Slot after | Runs a destructor |
|---|---|---|---|
| `ptr.unsafe_write(value)` | uninitialized | initialized | no |
| `ptr[] = value` | initialized | initialized | yes, on the old value |
| `ptr.unsafe_take_pointee()` | initialized | uninitialized | no, the caller owns the value |
| `ptr.unsafe_deinit_pointee()` | initialized | uninitialized | yes |
| `dealloc(allocation^)` | any | freed | no, never for elements |

Getting the "before" column wrong is undefined behavior: `ptr[] = value`
on an uninitialized slot runs a destructor over undefined content, and
`unsafe_write` on a live slot leaks the old value.

```mojo
from std.memory import alloc, dealloc, ArcPointer, Layout
from std.testing import assert_equal


# The log lives behind an ArcPointer, so a Tracer carries no origin and can
# sit in heap storage next to other Tracers.
struct Tracer(Movable):
    var label: String
    var log: ArcPointer[List[String]]

    def __init__(out self, label: String, log: ArcPointer[List[String]]):
        self.label = label
        self.log = log

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def main() raises:
    var events = ArcPointer(List[String]())
    var allocation = alloc(Layout[Tracer](length=2))
    var slots = allocation.unsafe_ptr()
    slots.unsafe_write(Tracer("north", events))
    slots.unsafe_offset(1).unsafe_write(Tracer("south", events))
    events[].append("written")

    slots[] = Tracer("east", events)  # destroys "north"
    events[].append("assigned")

    var taken = slots.unsafe_offset(1).unsafe_take_pointee()
    events[].append("took " + taken.label)

    slots.unsafe_deinit_pointee()  # destroys "east" in place
    dealloc(allocation^)
    events[].append("freed")
    assert_equal(
        events[],
        [
            "written",
            "drop north",
            "assigned",
            "drop south",
            "took south",
            "drop east",
            "freed",
        ],
    )
```

[code/05-uninitialized-memory/pointer_write_assign_take.mojo](code/05-uninitialized-memory/pointer_write_assign_take.mojo)

`Pointer.write()` has no `unsafe_` prefix because its `where` clause only
admits trivially deinitializable types such as `Int64`. For those, no
destructor exists, so overwriting a live value loses nothing.

```mojo
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


def main() raises:
    var allocation = alloc(Layout[Int64](length=4))
    var counters = allocation.unsafe_ptr()
    for index in range(4):
        counters.unsafe_offset(index).write(Int64(index * 100))
    counters.unsafe_offset(2).write(Int64(250))  # overwrite, no leak possible
    var patched = counters[unsafe_offset=2]
    var last = counters[unsafe_offset=3]
    dealloc(allocation^)  # before any assert: a raise must not skip it
    assert_equal(patched, 250)
    assert_equal(last, 300)
```

[code/05-uninitialized-memory/write_overwrites_trivial.mojo](code/05-uninitialized-memory/write_overwrites_trivial.mojo)

For a type with a destructor, `write()` doesn't compile, and you have to
choose the unsafe operation that matches the slot's state.

```mojo
from std.memory import alloc, dealloc, Layout


def main():
    var allocation = alloc(Layout[String](length=1))
    var slot = allocation.unsafe_ptr()
    slot.write(String("payload"))
    dealloc(allocation^)
```

[code/05-uninitialized-memory/write_requires_trivial_fails.mojo](code/05-uninitialized-memory/write_requires_trivial_fails.mojo)

The `Allocation` that owns the storage is a linear type: it doesn't conform
to `Deinitable`, so Mojo never destroys it on its own. Forgetting `dealloc()`
is a compile error, not a leak.

```mojo
from std.memory import alloc, Layout


def main():
    var allocation = alloc(Layout[Int](length=4))
    var slots = allocation.unsafe_ptr()
    slots.write(7)
    print(slots[])
```

[code/05-uninitialized-memory/allocation_abandoned_fails.mojo](code/05-uninitialized-memory/allocation_abandoned_fails.mojo)

That linearity reaches into error paths. `assert_equal` can raise, and a
raise that skips `dealloc()` abandons the `Allocation`, so the compiler
rejects any sample that asserts while it still holds one. The samples in this
section read their results into locals, release their storage, and assert
last.

### `MaybeUninit`

`MaybeUninit[T]` holds storage for one `T` with the same size as `T`. Its
default constructor leaves the storage uninitialized. You fill it with
`unsafe_write()` and read it with `unsafe_assume_init()`, which has two
overloads: on a reference, it borrows the value; on an owned wrapper
(`slot^`), it moves the value out and ends the wrapper.

```mojo
from std.memory import MaybeUninit
from std.testing import assert_equal


def main() raises:
    var slot = MaybeUninit[String]()
    slot.unsafe_write(String("payload"))
    var length = slot.unsafe_assume_init().byte_length()
    var owned = slot^.unsafe_assume_init()  # resolve the wrapper before raising
    assert_equal(length, 7)
    assert_equal(owned, "payload")
```

[code/05-uninitialized-memory/maybe_uninit_roundtrip.mojo](code/05-uninitialized-memory/maybe_uninit_roundtrip.mojo)

`MaybeUninit` never runs `T`'s destructor, because it can't know whether a
`T` lives inside. When `T` has a destructor, that makes the wrapper itself
linear: you must resolve it on every path with `unsafe_assume_init()`,
`unsafe_deinit()`, or `unsafe_forget()`.

```mojo
from std.memory import MaybeUninit


def main():
    var slot = MaybeUninit[String]()
    slot.unsafe_write(String("payload"))
    print(slot.unsafe_assume_init())
```

[code/05-uninitialized-memory/maybe_uninit_abandoned_fails.mojo](code/05-uninitialized-memory/maybe_uninit_abandoned_fails.mojo)

The conformance carries a `where` condition, so `MaybeUninit[Int]` is an
ordinary value that Mojo destroys implicitly, while `MaybeUninit[String]` is
not.

```mojo
from std.memory import MaybeUninit
from std.sys import size_of
from std.testing import assert_equal, assert_true, assert_false


def main() raises:
    assert_equal(size_of[MaybeUninit[String]](), size_of[String]())
    assert_equal(size_of[MaybeUninit[Float64]](), 8)
    assert_true(conforms_to(MaybeUninit[Int], Deinitable))
    assert_false(conforms_to(MaybeUninit[String], Deinitable))
```

[code/05-uninitialized-memory/maybe_uninit_conditional_conformance.mojo](code/05-uninitialized-memory/maybe_uninit_conditional_conformance.mojo)

`MaybeUninit.zeroed()` fills the storage with zero bytes. Whether that counts
as initialized depends on `T`. Zero bytes form a valid `Int`. They don't form
a valid `String`, so for `String` the slot stays uninitialized in every sense
that matters. For trivially deinitializable types, `write()` overwrites
freely.

```mojo
from std.memory import MaybeUninit
from std.testing import assert_equal


def main() raises:
    var hits = MaybeUninit[Int].zeroed()
    assert_equal(hits.unsafe_assume_init(), 0)
    hits.write(5500)
    hits.write(5600)
    assert_equal(hits.unsafe_assume_init(), 5600)
```

[code/05-uninitialized-memory/maybe_uninit_zeroed_and_write.mojo](code/05-uninitialized-memory/maybe_uninit_zeroed_and_write.mojo)

### Initializing and destroying in bulk

A `Span` over `MaybeUninit` elements has helpers that initialize every
element and return a span typed as the initialized element type:
`unsafe_init_with()` calls a function with each index, and
`unsafe_init_copy_from()` copies from a source span of the same length. On
the way out, `unsafe_deinit_elements()` runs every element's destructor.

An `Array` of `MaybeUninit[String]` is not `Deinitable`, for the same reason
a single `MaybeUninit[String]` isn't. After destroying the strings, you
dispose of the empty wrappers through `deinit_with()`.

```mojo
from std.memory import MaybeUninit
from std.testing import assert_equal


def forget_slot(var slot: MaybeUninit[String]):
    slot^.unsafe_forget()  # the String inside is already destroyed


def main() raises:
    var storage = Array[MaybeUninit[Int], 5]()
    var squares = Span(storage).unsafe_init_with(
        lambda (index: Int) -> Int: index * index
    )
    assert_equal(squares[4], 16)

    var source: Array[String, 2] = ["inlet", "outlet"]
    var names = Array[MaybeUninit[String], 2]()
    var copied = Span(names).unsafe_init_copy_from(source)
    var second = copied[1]
    copied.unsafe_deinit_elements()
    names^.deinit_with(forget_slot)  # resolve before any assert can raise
    assert_equal(second, "outlet")
```

[code/05-uninitialized-memory/span_init_helpers.mojo](code/05-uninitialized-memory/span_init_helpers.mojo)

`Allocation.storage()` presents fresh heap memory as
`Span[MaybeUninit[T]]`, so heap initialization uses the same helpers. For a
type that is not `Movable`, `unsafe_write(init_with=)` constructs the value
directly in the slot instead of moving a finished value in.

```mojo
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


@fieldwise_init
struct Listener(not Movable):
    var port: Int


def main() raises:
    var allocation = alloc(Layout[String](length=3))
    var stages = allocation.storage().unsafe_init_with(
        lambda (index: Int) -> String: String("stage-", index)
    )
    var last_stage = stages[2]
    stages.unsafe_deinit_elements()
    dealloc(allocation^)
    assert_equal(last_stage, "stage-2")

    var slot = alloc(Layout[Listener].single())
    var listener = slot.unsafe_ptr()
    listener.unsafe_write(init_with=lambda () -> Listener: Listener(8080))
    var port = listener[].port
    listener.unsafe_deinit_pointee()
    dealloc(slot^)
    assert_equal(port, 8080)
```

[code/05-uninitialized-memory/allocation_storage_init.mojo](code/05-uninitialized-memory/allocation_storage_init.mojo)

`std.memory` provides range operations over raw pointers:

- `unsafe_uninit_move_n` relocates initialized values into uninitialized
  memory and leaves the source uninitialized. After the move, freeing the
  source destroys nothing, which is how a growable buffer reallocates.
- `unsafe_uninit_copy_n` duplicates values into uninitialized memory and
  leaves the source intact.
- `unsafe_destroy_n` runs destructors over a range. For trivially
  deinitializable types it compiles to nothing.

Each takes `overlapping` as a compile-time parameter. Pass `True` when the
ranges can overlap; the move then picks a safe direction.

```mojo
from std.memory import (
    alloc,
    dealloc,
    Layout,
    unsafe_uninit_move_n,
    unsafe_uninit_copy_n,
    unsafe_destroy_n,
)
from std.testing import assert_equal


def main() raises:
    var old = alloc(Layout[String](length=3))
    var stages = old.unsafe_ptr()
    stages.unsafe_write("inlet")
    stages.unsafe_offset(1).unsafe_write("pump")
    stages.unsafe_offset(2).unsafe_write("outlet")

    var grown = alloc(Layout[String](length=6))
    unsafe_uninit_move_n[overlapping=False](
        dest=grown.unsafe_ptr(), src=old.unsafe_ptr(), count=3
    )
    dealloc(old^)  # nothing left to destroy in the old block

    var data = grown.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    unsafe_uninit_copy_n[overlapping=False](
        dest=data.unsafe_offset(3), src=data, count=3
    )
    var copied = data[unsafe_offset=4]
    unsafe_destroy_n(data, 6)
    dealloc(grown^)
    assert_equal(copied, "pump")
```

[code/05-uninitialized-memory/bulk_move_copy_destroy.mojo](code/05-uninitialized-memory/bulk_move_copy_destroy.mojo)

That sample casts one pointer to `MutUntrackedOrigin` before the copy.
Exclusivity checking works on origins, not address ranges. Two pointers into
the same allocation share its origin, so passing one as `dest` and the other
as `src` looks like mutable aliasing to the checker, even when the ranges
don't overlap. Casting one side to an untracked origin opts that call out of
the check, and you take over the proof that the ranges are disjoint.

```mojo
from std.memory import alloc, dealloc, Layout, unsafe_uninit_copy_n


def main():
    var grown = alloc(Layout[Int64](length=6))
    var data = grown.unsafe_ptr()
    for index in range(3):
        data.unsafe_offset(index).write(Int64(index))
    unsafe_uninit_copy_n[overlapping=False](
        dest=data.unsafe_offset(3), src=data, count=3
    )
    dealloc(grown^)
```

[code/05-uninitialized-memory/same_origin_aliasing_fails.mojo](code/05-uninitialized-memory/same_origin_aliasing_fails.mojo)
