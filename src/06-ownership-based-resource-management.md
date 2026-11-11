# 6. Ownership-based resource management

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/traits/anytype.mojo, Mojo/stdlib/std/traits/deinitable.mojo, Mojo/stdlib/std/traits/movable.mojo, Mojo/stdlib/std/traits/copyable.mojo, Mojo/stdlib/std/memory/alloc.mojo, Mojo/stdlib/std/memory/memory.mojo, Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/memory/arc_pointer.mojo, Mojo/stdlib/std/collections/list.mojo -->

How Mojo constructs, moves, copies, destroys, and leaks values, and how linear types turn forgotten cleanup into compile errors.

A Mojo value has a life with four checkpoints: something constructs it, code
uses it, ownership may move, and something ends it. The compiler tracks every
checkpoint. It knows which bindings hold an initialized value at each point in
the program, and it inserts destructor calls where values stop being used.

That tracking is what makes resource management automatic, and it is also
what you take over when you write unsafe code. This chapter covers the rules
the compiler follows, so that code which takes over can follow the same ones.

Every sample in this chapter lives in
[code/06-ownership-based-resource-management/](code/06-ownership-based-resource-management/).
Samples whose names end in `_fails` are compile-error demonstrations: the
test runner checks that they fail, and that they fail for the stated reason.

## 6.1 Constructors

*Rustonomicon counterpart: Constructors.*

A constructor is an `__init__` method whose first argument is `out self`.
The `out` convention hands the method a block of uninitialized storage, and
the method's job is to initialize every field of it. Nothing is
default-initialized: a field you don't assign stays uninitialized, and the
compiler won't let the constructor return in that state.

`@fieldwise_init` writes the obvious constructor for you, one argument per
field in declaration order. You can also delegate: a constructor may build a
complete value some other way and assign it to `self`. The `out` convention
is not limited to `__init__`. Any function can name its result with `out` and
initialize it in place.

```mojo
# Claims:
# - `@fieldwise_init` synthesizes an `__init__` that takes one argument per field.
# - `out self` names uninitialized storage; the constructor must initialize
#   every field before it returns.
# - A constructor can delegate by assigning a whole value to `self`.
# - Any function can name its result with `out`, and initializes it in place.
from std.testing import assert_equal


@fieldwise_init
struct Reading(Copyable):
    var sensor: String
    var celsius: Float64


struct Calibration(Movable):
    var offset: Float64
    var scale: Float64

    def __init__(out self, offset: Float64, scale: Float64):
        self.offset = offset
        self.scale = scale

    def __init__(out self):
        # Delegation: build a complete value and assign it to `self`.
        self = Self(offset=0.0, scale=1.0)


def zeroed_reading(sensor: String, out reading: Reading):
    reading = Reading(sensor, 0.0)


def main() raises:
    var reading = Reading("intake", 21.5)
    assert_equal(reading.sensor, "intake")

    var identity = Calibration()
    assert_equal(identity.scale, 1.0)

    var baseline = zeroed_reading("exhaust")
    assert_equal(baseline.celsius, 0.0)
```

[code/06-ownership-based-resource-management/fieldwise_init_and_out_self.mojo](code/06-ownership-based-resource-management/fieldwise_init_and_out_self.mojo)

The initialization check covers every path out of the constructor, including
early returns and branches:

```mojo
# EXPECT-ERROR: the constructor returns while one field is still uninitialized
# EXPECT-MATCH: self\.longitude' is uninitialized
# Claim: every path out of an `out self` constructor must initialize every field.


struct Waypoint:
    var latitude: Float64
    var longitude: Float64

    def __init__(out self, latitude: Float64):
        self.latitude = latitude


def main():
    _ = Waypoint(37.77)
```

[code/06-ownership-based-resource-management/partial_init_fails.mojo](code/06-ownership-based-resource-management/partial_init_fails.mojo)

### Copying is opt-in, and implicit copying is a second opt-in

`Copyable` gives a type a copy constructor, `__init__(out self, *, copy:
Self)`. If every field is `Copyable` and you don't write one, the compiler
synthesizes a copy constructor that copies each field. Copying a struct that
holds a `List` copies the list's elements; the copies share no storage.

```mojo
# Claims:
# - Declaring `Copyable` on a struct whose fields are all Copyable gets a
#   synthesized copy constructor that copies each field.
# - Copying a struct that holds a List copies the List's elements, so the two
#   values share no storage.
# - Every struct is Movable without declaring it.
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Playlist(Copyable):
    var title: String
    var track_ids: List[Int]


struct Plain:
    var count: Int


def main() raises:
    var original = Playlist("focus", [4021, 4022, 4030])
    var remix = original.copy()
    remix.track_ids.append(5100)
    assert_equal(len(original.track_ids), 3)
    assert_equal(len(remix.track_ids), 4)
    assert_true(
        original.track_ids.unsafe_ptr() != remix.track_ids.unsafe_ptr()
    )
    comptime assert conforms_to(Plain, Movable)
```

[code/06-ownership-based-resource-management/synthesized_copy_is_deep.mojo](code/06-ownership-based-resource-management/synthesized_copy_is_deep.mojo)

`Copyable` alone doesn't make `=` copy. A type copies implicitly only if it
also conforms to `ImplicitlyCopyable`, which most heap-owning types decline.
Without it, the compiler asks you to pick between `.copy()` and a transfer
with `^`:

```mojo
# EXPECT-ERROR: a Copyable type that is not ImplicitlyCopyable needs an explicit copy or transfer
# EXPECT-MATCH: cannot be implicitly copied
# Claim: `Copyable` alone does not let `=` copy a value; write `.copy()` or `^`.


@fieldwise_init
struct Firmware(Copyable):
    var image: List[UInt8]


def main():
    var shipped = Firmware([0x7F, 0x45, 0x4C, 0x46])
    var staged = shipped
    print(len(staged.image), len(shipped.image))
```

[code/06-ownership-based-resource-management/implicit_copy_fails.mojo](code/06-ownership-based-resource-management/implicit_copy_fails.mojo)

The design choice behind this: a copy that allocates should be visible at
the call site.

### Moves, transfers, and the move constructor

The move constructor is `__init__(out self, *, deinit move: Self)`. The
`deinit` convention on `move` means the constructor receives the source in a
state where its destructor will not run; the new value inherits
responsibility for whatever the source owned. The argument must be named
`move`. The compiler warns that a `deinit` argument with any other name does
not define a move constructor, and it then never calls that `__init__` for
moves.

Every struct is `Movable` unless it opts out, and the compiler synthesizes a
move constructor that moves each field. Write your own only when a move needs
to do more than relocate the fields' bits.

The `^` sigil means "transfer ownership". Whether a transfer runs the move
constructor depends on where the value goes:

| Operation | Move constructor runs? |
|---|---|
| `var dest = source^` | Yes: the value relocates to new storage |
| `return local^` | Yes |
| `consume(source^)` into a `var` argument | No: the callee takes over the caller's storage |
| `source^.finish()` into a `deinit self` method | No |

```mojo
# Claims:
# - The move constructor is `__init__(out self, *, deinit move: Self)`.
# - `var dest = source^` runs the move constructor.
# - Passing `source^` to a `var` argument hands over ownership without a move:
#   the callee owns the caller's storage.
# - `return local^` runs the move constructor.
# - A move never runs `__deinit__` on the source; the destination inherits
#   responsibility for destruction.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Frame(Copyable, Movable):
    var payload: String
    var moves: ArcPointer[Int]
    var deinits: ArcPointer[Int]

    def __init__(
        out self,
        payload: String,
        moves: ArcPointer[Int],
        deinits: ArcPointer[Int],
    ):
        self.payload = payload
        self.moves = moves
        self.deinits = deinits

    def __init__(out self, *, copy: Self):
        self.payload = copy.payload
        self.moves = copy.moves
        self.deinits = copy.deinits

    def __init__(out self, *, deinit move: Self):
        self.payload = move.payload^
        self.moves = move.moves^
        self.deinits = move.deinits^
        self.moves[] += 1

    def __deinit__(deinit self):
        self.deinits[] += 1


def consume(var frame: Frame) -> Int:
    return frame.payload.byte_length()


def build(moves: ArcPointer[Int], deinits: ArcPointer[Int]) -> Frame:
    var local = Frame("handshake", moves, deinits)
    return local^


def main() raises:
    var moves = ArcPointer(0)
    var deinits = ArcPointer(0)

    var first = Frame("syn", moves, deinits)
    var second = first^
    assert_equal(moves[], 1)
    assert_equal(deinits[], 0)

    _ = consume(second^)
    assert_equal(moves[], 1)
    assert_equal(deinits[], 1)

    var built = build(moves, deinits)
    assert_equal(moves[], 2)
    assert_equal(built.payload, "handshake")
```

[code/06-ownership-based-resource-management/move_constructor_calls.mojo](code/06-ownership-based-resource-management/move_constructor_calls.mojo)

### Pinned types

`not Movable` opts a type out of relocation. That is the right choice for a
value whose address matters: a lock that other threads point at, a node in an
intrusive list, a register block at a fixed address.

`not Movable` does not forbid `^`. Transferring into a `var` argument or into
a `deinit` method consumes the value where it already lives, so a pinned
value can still be handed off and destroyed. A function can also return a
freshly constructed pinned value.

```mojo
# Claims:
# - `not Movable` opts a struct out of relocation.
# - A non-Movable value can still transfer with `^` into a `var` argument
#   or a `deinit` method, because those consume it in place.
# - A function can return a freshly constructed non-Movable value.
from std.testing import assert_equal


struct SpinLockSlot(not Movable):
    var owner_id: Int

    def __init__(out self, owner_id: Int):
        self.owner_id = owner_id

    def release(deinit self) -> Int:
        return self.owner_id


def adopt(var slot: SpinLockSlot) -> Int:
    return slot.owner_id


def fresh_slot(owner_id: Int) -> SpinLockSlot:
    return SpinLockSlot(owner_id)


def main() raises:
    var slot = SpinLockSlot(41)
    assert_equal(adopt(slot^), 41)

    var made = fresh_slot(42)
    assert_equal(made^.release(), 42)
```

[code/06-ownership-based-resource-management/pinned_not_movable.mojo](code/06-ownership-based-resource-management/pinned_not_movable.mojo)

What `not Movable` forbids is relocation: binding the value to new storage.

```mojo
# EXPECT-ERROR: transferring a non-Movable value into a new binding needs relocation
# EXPECT-MATCH: doesn't conform to 'Movable'
# Claim: `var dest = source^` relocates, so it requires Movable.


struct SpinLockSlot(not Movable):
    var owner_id: Int

    def __init__(out self, owner_id: Int):
        self.owner_id = owner_id


def main():
    var slot = SpinLockSlot(7)
    var relocated = slot^
    print(relocated.owner_id)
```

[code/06-ownership-based-resource-management/pinned_transfer_fails.mojo](code/06-ownership-based-resource-management/pinned_transfer_fails.mojo)

### Constructing in place

Raw memory needs a way to construct a value where it will live.
`Pointer.unsafe_write(init_with=...)` calls a function and stores its result
directly at the pointer's address, so the type doesn't need to be `Movable`.
The usual raw-memory contract applies: the memory must not already hold a
live value, and you end the value's lifetime in place with
`unsafe_deinit_pointee()` before you release the storage.

```mojo
# Claims:
# - `unsafe_write(init_with=...)` constructs a value directly in raw memory,
#   so the type does not need to be Movable.
# - The value then lives at the allocation's address and nowhere else.
# - You end its lifetime in place with `unsafe_deinit_pointee()` before
#   releasing the storage.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal, assert_true


struct DeviceRegister(not Movable):
    var address: Int
    var value: UInt32

    def __init__(out self, address: Int):
        self.address = address
        self.value = 0


def main() raises:
    var storage = alloc(Layout[DeviceRegister].single())
    var slot = storage.unsafe_ptr()
    slot.unsafe_write(init_with=lambda () -> DeviceRegister: DeviceRegister(0x4000_1000))
    slot[].value = 0xFF
    # Read everything before releasing: `assert_*` can raise, and the
    # compiler rejects a raise while `storage` is still live.
    var address = slot[].address
    var value = slot[].value
    var emplaced_in_place = Int(Pointer(to=slot[])) == Int(storage.unsafe_ptr())
    slot.unsafe_deinit_pointee()
    dealloc(storage^)
    assert_equal(address, 0x4000_1000)
    assert_equal(value, 0xFF)
    assert_true(emplaced_in_place)
```

[code/06-ownership-based-resource-management/emplace_init_with.mojo](code/06-ownership-based-resource-management/emplace_init_with.mojo)

Notice where the assertions sit in that sample. `assert_equal` can raise,
and `storage` is a linear `Allocation`, so the compiler rejects any raise
while it is still live (see [7.2 Poisoning](07-unwinding.md#72-poisoning)).
The sample reads what it needs, releases the storage, and asserts afterward.

## 6.2 Destructors

*Rustonomicon counterpart: Destructors.*

The implicit destructor is `__deinit__(deinit self)`. Types that have one
conform to `Deinitable`, and every struct conforms by default. If you don't
write a `__deinit__`, the compiler synthesizes one that destroys each field.

### ASAP destruction

Mojo destroys a value after its last use, not at the end of its scope. The
granularity is finer than a statement: a value can die in the middle of an
expression, as soon as its last read finishes. In the sample below,
`request` dies while Mojo builds the string `"handle " + request.name`,
before `append` runs.

```mojo
# Claims:
# - Mojo destroys a value after its last use, not at the end of the scope.
# - A value that is never used after construction dies right away.
# - "Last use" is finer than a statement: here `request` dies as soon as
#   `"handle " + request.name` finishes evaluating, before `append` runs.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Span(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(out self, name: String, journal: ArcPointer[List[String]]):
        self.name = name
        self.journal = journal
        self.journal[].append("open " + name)

    def __deinit__(deinit self):
        self.journal[].append("close " + self.name)


def main() raises:
    var journal = ArcPointer(List[String]())

    var request = Span("request", journal)
    journal[].append("handle " + request.name)
    journal[].append("respond")
    _ = Span("unused", journal)
    journal[].append("done")

    assert_equal(
        journal[],
        [
            "open request",
            "close request",
            "handle request",
            "respond",
            "open unused",
            "close unused",
            "done",
        ],
    )
```

[code/06-ownership-based-resource-management/asap_destruction_order.mojo](code/06-ownership-based-resource-management/asap_destruction_order.mojo)

Two consequences matter for resource code:

1. A guard object with no later uses dies immediately after construction.
   Code that relies on a guard "holding" until the end of a block has to
   use the guard at the end of the block.
2. A destructor runs no earlier than the value's last use, but you shouldn't
   depend on the exact instruction where it runs. When the moment matters,
   pin it explicitly.

The builtin `deinit(value^)` pins it. It takes ownership of the value and
destroys it at that call, which makes the call the value's last use:

```mojo
# Claims:
# - A guard with no later uses dies right after construction, so its
#   destructor runs earlier than a scope-based reading suggests.
# - `deinit(guard^)` pins the end of the guard's life to that call.
from std.testing import assert_equal


struct DepthGuard[origin: MutOrigin](Movable):
    var depth: Pointer[Int, Self.origin]

    def __init__(out self, ref[Self.origin] depth: Int):
        depth += 1
        self.depth = Pointer(to=depth)

    def __deinit__(deinit self):
        self.depth[] -= 1


def main() raises:
    var unpinned_depth = 0
    _ = DepthGuard(unpinned_depth)
    assert_equal(unpinned_depth, 0)

    var depth = 0
    var guard = DepthGuard(depth)
    assert_equal(depth, 1)
    deinit(guard^)
    assert_equal(depth, 0)
```

[code/06-ownership-based-resource-management/deinit_extends_guard.mojo](code/06-ownership-based-resource-management/deinit_extends_guard.mojo)

### Field destruction order

Without a custom `__deinit__`, fields die in declaration order, regardless of
the order the constructor initialized them.

With a custom `__deinit__`, the `deinit self` argument turns every field into
an ordinary owned value inside the body, and each field follows the ASAP
rule on its own. A field the body never touches dies before the body's first
statement. A field the body reads dies right after that read. The sample
records both cases.

```mojo
# Claims:
# - Fields of a struct with no custom `__deinit__` die in declaration order,
#   regardless of the order `__init__` initialized them.
# - Inside a custom `__deinit__`, fields are ordinary owned values: each one
#   dies after its own last use in the body. A field the body never touches
#   dies before the body's first statement. A field read inside an
#   expression dies as soon as that read finishes, even mid-statement.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Part(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(out self, name: String, journal: ArcPointer[List[String]]):
        self.name = name
        self.journal = journal

    def __deinit__(deinit self):
        self.journal[].append("drop " + self.name)


struct Engine(Movable):
    var crankshaft: Part
    var piston: Part

    def __init__(out self, journal: ArcPointer[List[String]]):
        self.piston = Part("piston", journal)
        self.crankshaft = Part("crankshaft", journal)


struct Gearbox(Movable):
    var housing: Part
    var clutch: Part
    var journal: ArcPointer[List[String]]

    def __init__(out self, journal: ArcPointer[List[String]]):
        self.housing = Part("housing", journal)
        self.clutch = Part("clutch", journal)
        self.journal = journal

    def __deinit__(deinit self):
        self.journal[].append("gearbox body starts")
        self.journal[].append("inspect " + self.clutch.name)
        self.journal[].append("gearbox body ends")


def main() raises:
    var journal = ArcPointer(List[String]())
    _ = Engine(journal)
    assert_equal(journal[], ["drop crankshaft", "drop piston"])

    journal[].clear()
    _ = Gearbox(journal)
    assert_equal(
        journal[],
        [
            "drop housing",
            "gearbox body starts",
            "drop clutch",
            "inspect clutch",
            "gearbox body ends",
        ],
    )
```

[code/06-ownership-based-resource-management/field_destruction_order.mojo](code/06-ownership-based-resource-management/field_destruction_order.mojo)

So a destructor that must tear things down in a specific order has to say so
in code: move fields out with `^`, or pass them to `deinit(...)` in the order
you need.

### Named destructors

A method that takes `deinit self` is a named destructor. Calling it consumes
the value, and `__deinit__` does not run afterward. Inside the method, the
fields are yours: you can move them out, return them, or pass them on.

```mojo
# Claims:
# - A method taking `deinit self` is a named destructor: calling it consumes
#   the value, and `__deinit__` does not run afterward.
# - Inside a `deinit self` method you can move fields out of `self`.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Session(Movable):
    var token: String
    var implicit_logouts: ArcPointer[Int]

    def __init__(out self, token: String, implicit_logouts: ArcPointer[Int]):
        self.token = token
        self.implicit_logouts = implicit_logouts

    def __deinit__(deinit self):
        self.implicit_logouts[] += 1

    def hand_off_token(deinit self) -> String:
        return self.token^


def main() raises:
    var implicit_logouts = ArcPointer(0)

    _ = Session("tok-31f9", implicit_logouts)
    assert_equal(implicit_logouts[], 1)

    var session = Session("tok-77a2", implicit_logouts)
    var token = session^.hand_off_token()
    assert_equal(token, "tok-77a2")
    assert_equal(implicit_logouts[], 1)
```

[code/06-ownership-based-resource-management/named_destructor_skips_deinit.mojo](code/06-ownership-based-resource-management/named_destructor_skips_deinit.mojo)

### Linear types

A struct declared `not Deinitable` has no implicit destructor at all. The
only way to end one of its values is a named destructor, and the compiler
rejects every path that lets a value reach the end of its life without one.
An optional `else "..."` message joins the compiler's diagnostic, so the
type can tell its users what to do.

```mojo
# EXPECT-ERROR: a linear value reaches the end of its life without a named destructor
# EXPECT-MATCH: abandoned without being explicitly destroyed: close the ticket with resolve
# Claim: `not Deinitable else "..."` makes abandoning a value a compile
# error, and the compiler appends your message to the diagnostic.


struct Ticket(not Deinitable else "close the ticket with resolve() or escalate()"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self):
        pass

    def escalate(deinit self) -> Int:
        return self.id


def main():
    var ticket = Ticket(4417)
    print(ticket.id)
```

[code/06-ownership-based-resource-management/linear_ticket_fails.mojo](code/06-ownership-based-resource-management/linear_ticket_fails.mojo)

Different paths may end the value with different named destructors:

```mojo
# Claims:
# - A linear (`not Deinitable`) value is legal once every path ends it
#   through a named `deinit` method.
# - Different branches may pick different named destructors.
from std.testing import assert_equal


struct Ticket(not Deinitable else "close the ticket with resolve() or escalate()"):
    var id: Int
    var severity: Int

    def __init__(out self, id: Int, severity: Int):
        self.id = id
        self.severity = severity

    def resolve(deinit self) -> Int:
        return 0

    def escalate(deinit self) -> Int:
        return self.id


def triage(var ticket: Ticket) -> Int:
    if ticket.severity >= 3:
        return ticket^.escalate()
    return ticket^.resolve()


def main() raises:
    assert_equal(triage(Ticket(4417, severity=4)), 4417)
    assert_equal(triage(Ticket(4418, severity=1)), 0)
```

[code/06-ownership-based-resource-management/linear_ticket_resolved.mojo](code/06-ownership-based-resource-management/linear_ticket_resolved.mojo)

Linearity propagates. A struct with a linear field cannot have an implicit
destructor, because that destructor would have no way to end the field:

```mojo
# EXPECT-ERROR: a struct with an implicit destructor cannot hold a linear field
# EXPECT-MATCH: field 'open_ticket' has non-'Deinitable' type
# Claim: linearity propagates. A struct that contains a `not Deinitable`
# field must itself be `not Deinitable` (or conditionally Deinitable).


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self):
        pass


struct HelpDesk:
    var open_ticket: Ticket

    def __init__(out self):
        self.open_ticket = Ticket(1)


def main():
    pass
```

[code/06-ownership-based-resource-management/linear_field_needs_linear_owner_fails.mojo](code/06-ownership-based-resource-management/linear_field_needs_linear_owner_fails.mojo)

The containing struct has to be linear too, and its own named destructors
must end every linear field. Running a `deinit self` method doesn't excuse
the fields inside it:

```mojo
# EXPECT-ERROR: a named destructor forgets to end a linear field
# EXPECT-MATCH: 'self' abandoned without being explicitly destroyed
# Claim: inside a `deinit self` method, every linear field still needs its
# own named destructor before the method returns.


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self):
        pass


struct HelpDesk(not Deinitable):
    var open_ticket: Ticket
    var clerk: String

    def __init__(out self):
        self.open_ticket = Ticket(1)
        self.clerk = "ana"

    def close_for_day(deinit self):
        print("closing", self.clerk)


def main():
    var desk = HelpDesk()
    desk^.close_for_day()
```

[code/06-ownership-based-resource-management/linear_owner_must_end_fields_fails.mojo](code/06-ownership-based-resource-management/linear_owner_must_end_fields_fails.mojo)

### Conditional destructibility

Generic code has to decide what to do with a `T` that might be linear. A
field of type `T` requires one of two things: a `T: Deinitable` bound, or a
conditional conformance on the containing struct. The conditional form,
`Deinitable where conforms_to(T, Deinitable)`, gives the struct an implicit
destructor exactly when its contents have one. For linear contents, the
caller must use a named destructor, and the `else` message explains how.

```mojo
# Claims:
# - `Deinitable where <condition>` makes a generic struct implicitly
#   destructible only for element types that are.
# - The same struct then works with linear elements, provided the caller
#   ends it through a named `deinit` method.
# - A generic field of type `T` needs this: without `T: Deinitable` or a
#   conditional conformance, the field is rejected.
from std.testing import assert_equal


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self) -> Int:
        return self.id


struct Envelope[T: Movable](
    Movable,
    Deinitable where conforms_to(T, Deinitable) else (
        "an Envelope of linear contents must be opened with open()"
    ),
):
    var contents: Self.T

    def __init__(out self, var contents: Self.T):
        self.contents = contents^

    def open(deinit self) -> Self.T:
        return self.contents^


def main() raises:
    var letter = Envelope[String]("invoice #2231")
    assert_equal(letter.contents, "invoice #2231")

    var sealed = Envelope[Ticket](Ticket(88))
    var ticket = sealed^.open()
    assert_equal(ticket^.resolve(), 88)
```

[code/06-ownership-based-resource-management/conditional_deinitable.mojo](code/06-ownership-based-resource-management/conditional_deinitable.mojo)

`List` uses this same pattern. A list of linear elements is itself linear,
and `deinit_with` ends it by handing each element to your function by value:

```mojo
# Claims:
# - A List can hold linear elements; inserting needs only Movable.
# - Such a List is itself linear: end it with `deinit_with`, which hands
#   each element to your function by value.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self) -> Int:
        return self.id


def main() raises:
    var resolved = ArcPointer(List[Int]())
    var backlog = List[Ticket]()
    backlog.append(Ticket(301))
    backlog.append(Ticket(302))
    backlog.append(Ticket(303))

    def close_ticket(var ticket: Ticket) {var resolved}:
        resolved[].append(ticket^.resolve())

    backlog^.deinit_with(close_ticket)
    assert_equal(resolved[], [301, 302, 303])
```

[code/06-ownership-based-resource-management/list_of_linear_deinit_with.mojo](code/06-ownership-based-resource-management/list_of_linear_deinit_with.mojo)

```mojo
# EXPECT-ERROR: a List of linear elements cannot die implicitly
# EXPECT-MATCH: Use `deinit_with\(\)` to explicitly destroy
# Claim: List's conditional conformance carries its own guidance message.


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self):
        pass


def main():
    var backlog = List[Ticket]()
    backlog.append(Ticket(301))
    print(len(backlog))
```

[code/06-ownership-based-resource-management/list_of_linear_abandoned_fails.mojo](code/06-ownership-based-resource-management/list_of_linear_abandoned_fails.mojo)

## 6.3 Leaking

*Rustonomicon counterpart: Leaking.*

Ownership-based resource management promises that destructors run. It
cannot promise that they run on every value, because a program can always
keep a value alive forever. Mojo draws the line here: leaking is safe.
Code may fail to run a destructor; code may never run a destructor twice,
or touch a value after its destructor ran.

### `forget_deinit`

`forget_deinit(value^)` consumes a value and skips its destructor, and the
destructors of all its fields, recursively. It's a safe function. A leak
can exhaust memory or hold a lock file forever, but it cannot make the
program read freed memory.

```mojo
# Claims:
# - `forget_deinit` consumes a value without running its destructor, or the
#   destructors of any of its fields.
# - It is a safe function: skipping a destructor can leak, but cannot by
#   itself corrupt memory.
from std.memory import ArcPointer, forget_deinit
from std.testing import assert_equal


struct Lease(Movable):
    var holder: String
    var releases: ArcPointer[Int]

    def __init__(out self, holder: String, releases: ArcPointer[Int]):
        self.holder = holder
        self.releases = releases

    def __deinit__(deinit self):
        self.releases[] += 1


struct Tenancy(Movable):
    var primary: Lease
    var backup: Lease

    def __init__(out self, releases: ArcPointer[Int]):
        self.primary = Lease("node-a", releases)
        self.backup = Lease("node-b", releases)


def main() raises:
    var releases = ArcPointer(0)

    _ = Tenancy(releases)
    assert_equal(releases[], 2)

    var forgotten = Tenancy(releases)
    forget_deinit(forgotten^)
    assert_equal(releases[], 2)
    # Each forgotten Lease still holds an ArcPointer copy, so the counter's
    # strong count stays above one: the leak is observable.
    assert_equal(releases.count(), 3)
```

[code/06-ownership-based-resource-management/forget_deinit_is_safe.mojo](code/06-ownership-based-resource-management/forget_deinit_is_safe.mojo)

Mind the `^`. For an `ImplicitlyCopyable` type, `forget_deinit(value)`
without the sigil copies the value and forgets the copy. With `ArcPointer`,
that copy holds a strong reference, so the shared payload can never reach a
count of zero:

```mojo
# Claims:
# - Passing an ImplicitlyCopyable value to `forget_deinit` without `^`
#   forgets a fresh copy, not the original.
# - For ArcPointer, that copy holds a strong count, so forgetting it leaks
#   one reference: the payload can never reach a count of zero.
from std.memory import ArcPointer, forget_deinit
from std.testing import assert_equal


def main() raises:
    var config = ArcPointer(String("region=us-west-2"))
    assert_equal(config.count(), 1)

    forget_deinit(config)
    assert_equal(config.count(), 2)

    var spare = config
    forget_deinit(spare^)
    assert_equal(config.count(), 3)
```

[code/06-ownership-based-resource-management/forget_deinit_forgets_a_copy.mojo](code/06-ownership-based-resource-management/forget_deinit_forgets_a_copy.mojo)

### Leaking an allocation on purpose

`alloc(...)` returns an `Allocation`, which is linear: you end it with
`dealloc(handle^)` or with the named destructor `unsafe_leak()`.
`unsafe_leak()` returns the raw owning pointer and stops all compiler
tracking. The storage stays valid. Code that later rebuilds an `Allocation`
from that pointer, with the same `Layout`, takes ownership back.

```mojo
# Claims:
# - `Allocation.unsafe_leak()` is a named destructor: it ends the handle and
#   returns the raw owning pointer, which the compiler no longer tracks.
# - The storage stays valid after the leak.
# - `Allocation(unsafe_owned_ptr=..., layout=...)` takes ownership back, as
#   long as the layout matches the original `alloc` call.
from std.memory import alloc, dealloc, Allocation, Layout
from std.testing import assert_equal


def main() raises:
    comptime layout = Layout[Int64](length=3)
    var handle = alloc(layout)
    var raw = handle^.unsafe_leak()

    for index in range(3):
        raw.unsafe_offset(index).write(Int64(index * 1024))
    var last = raw[unsafe_offset=2]

    var reclaimed = Allocation(unsafe_owned_ptr=raw, layout=layout)
    dealloc(reclaimed^)
    assert_equal(last, 2048)
```

[code/06-ownership-based-resource-management/allocation_leak_and_reclaim.mojo](code/06-ownership-based-resource-management/allocation_leak_and_reclaim.mojo)

When you want the opposite (no explicit `dealloc` at all),
`into_managed()` converts the handle into a `ManagedAllocation`, which frees
its storage after its last use. It frees storage without running element
destructors, so it only accepts element types whose destructors are
trivial:

```mojo
# Claims:
# - `into_managed()` converts a linear Allocation into a ManagedAllocation,
#   which frees its storage in its destructor after its last use.
# - It frees storage without running element destructors.
from std.memory import alloc, Layout
from std.testing import assert_equal


def main() raises:
    var samples = alloc(Layout[Int32](length=8)).into_managed()
    var cursor = samples.unsafe_ptr()
    for index in range(len(samples)):
        cursor.unsafe_offset(index).write(Int32(index * index))
    assert_equal(cursor[unsafe_offset=7], 49)
    assert_equal(len(samples), 8)
```

[code/06-ownership-based-resource-management/managed_allocation.mojo](code/06-ownership-based-resource-management/managed_allocation.mojo)

```mojo
# EXPECT-ERROR: managed storage would skip element destructors, so it refuses types that have them
# EXPECT-MATCH: invalid call to 'into_managed': violated constraint
# Claim: `into_managed()` requires a trivially deinitializable element type,
# because ManagedAllocation never runs element destructors.
from std.memory import alloc, Layout


def main():
    var names = alloc(Layout[String](length=2)).into_managed()
    print(len(names))
```

[code/06-ownership-based-resource-management/managed_allocation_needs_trivial_fails.mojo](code/06-ownership-based-resource-management/managed_allocation_needs_trivial_fails.mojo)

### Reference cycles

`ArcPointer` destroys its payload when the strong count reaches zero. Two
payloads that hold strong pointers to each other keep both counts above
zero, so neither destructor ever runs. Nothing about this is unsafe: both
values stay valid and reachable through a weak pointer, long after every
local binding is gone.

```mojo
# Claims:
# - Two ArcPointers that point at each other keep each other alive: neither
#   strong count reaches zero, so neither destructor runs.
# - The leak is safe: the values stay valid and reachable through a weak
#   pointer, which can still upgrade after every local strong pointer dies.
from std.memory import ArcPointer
from std.memory.arc_pointer import WeakPointer
from std.testing import assert_equal, assert_true


struct Peer(Movable):
    var host: String
    var link: Optional[ArcPointer[Peer]]
    var closed: ArcPointer[Int]

    def __init__(out self, host: String, closed: ArcPointer[Int]):
        self.host = host
        self.link = None
        self.closed = closed

    def __deinit__(deinit self):
        self.closed[] += 1


def make_cycle(closed: ArcPointer[Int]) -> WeakPointer[Peer]:
    var east = ArcPointer(Peer("east.internal", closed))
    var west = ArcPointer(Peer("west.internal", closed))
    east[].link = west
    west[].link = east
    return WeakPointer(downgrade=east)


def main() raises:
    var closed = ArcPointer(0)
    var probe = make_cycle(closed)
    assert_equal(closed[], 0)

    var revived = probe.try_upgrade()
    assert_true(Bool(revived))
    assert_equal(revived.value()[].host, "east.internal")
    assert_equal(revived.value()[].link.value()[].host, "west.internal")
```

[code/06-ownership-based-resource-management/arc_cycle_leaks.mojo](code/06-ownership-based-resource-management/arc_cycle_leaks.mojo)

The fix is to make one direction of the link weak. A `WeakPointer` doesn't
keep the payload alive; it can only `try_upgrade()` while a strong pointer
still exists.

```mojo
# Claims:
# - Making one direction of the link weak breaks the ownership cycle.
# - When the last strong pointer dies, the destructor runs, and the weak
#   pointer can no longer upgrade.
from std.memory import ArcPointer
from std.memory.arc_pointer import WeakPointer
from std.testing import assert_equal, assert_false


struct Child(Movable):
    var name: String
    var parent: WeakPointer[Parent]

    def __init__(out self, name: String):
        self.name = name
        self.parent = WeakPointer[Parent]()


struct Parent(Movable):
    var name: String
    var children: List[ArcPointer[Child]]
    var closed: ArcPointer[Int]

    def __init__(out self, name: String, closed: ArcPointer[Int]):
        self.name = name
        self.children = List[ArcPointer[Child]]()
        self.closed = closed

    def __deinit__(deinit self):
        self.closed[] += 1


def build(closed: ArcPointer[Int]) -> WeakPointer[Parent]:
    var root = ArcPointer(Parent("cluster", closed))
    var leaf = ArcPointer(Child("node-7"))
    leaf[].parent = WeakPointer(downgrade=root)
    root[].children.append(leaf)
    return WeakPointer(downgrade=root)


def main() raises:
    var closed = ArcPointer(0)
    var probe = build(closed)
    assert_equal(closed[], 1)
    assert_false(Bool(probe.try_upgrade()))
```

[code/06-ownership-based-resource-management/weak_link_breaks_cycle.mojo](code/06-ownership-based-resource-management/weak_link_breaks_cycle.mojo)

### Staying sound when a destructor never runs

Because leaking is safe, unsafe code cannot rely on a destructor to restore
an invariant that soundness depends on. A guard that borrows a container and
temporarily breaks the container's invariants must leave the container in a
state that is still safe if the guard is forgotten.

The standard technique is leak amplification: before handing out anything,
the guard shrinks the container's view of what it owns. The `Drain` below
sets the queue's length to zero as its first act. From then on, the queue
believes it owns nothing, and the guard alone is responsible for the
remaining jobs:

1. If the `Drain` dies normally, its destructor destroys every job that no
   caller took.
2. If someone forgets the `Drain`, the remaining jobs leak, and the queue's
   own destructor sees a length of zero, so it destroys nothing twice.

```mojo
# Claims:
# - A guard that borrows a container must leave the container sound even if
#   the guard's destructor never runs.
# - Drain sets the queue's length to zero up front ("leak amplification").
#   Forgetting the Drain then leaks the remaining jobs instead of letting
#   the queue destroy them a second time.
# - When the Drain dies normally, its destructor destroys the jobs nobody
#   took.
from std.memory import (
    alloc,
    dealloc,
    Layout,
    Allocation,
    ArcPointer,
    forget_deinit,
    unsafe_destroy_n,
)
from std.testing import assert_equal


struct Job(Movable):
    var id: Int
    var retired: ArcPointer[Int]

    def __init__(out self, id: Int, retired: ArcPointer[Int]):
        self.id = id
        self.retired = retired

    def __deinit__(deinit self):
        self.retired[] += 1


struct JobQueue(Movable):
    var storage: Allocation[Job]
    var length: Int

    def __init__(out self, capacity: Int):
        self.storage = alloc(Layout[Job](length=capacity))
        self.length = 0

    def push(mut self, var job: Job):
        debug_assert(self.length < len(self.storage), "queue is full")
        self.storage.unsafe_ptr().unsafe_offset(self.length).unsafe_write(job^)
        self.length += 1

    def drain(mut self) -> Drain[origin_of(self)]:
        return Drain(self)

    def __deinit__(deinit self):
        unsafe_destroy_n(self.storage.unsafe_ptr(), self.length)
        dealloc(self.storage^)


struct Drain[origin: MutOrigin](Movable):
    var queue: Pointer[JobQueue, Self.origin]
    var next_index: Int
    var end: Int

    def __init__(out self, ref[Self.origin] queue: JobQueue):
        self.end = queue.length
        # Leak amplification: from here on, the queue owns no elements.
        queue.length = 0
        self.next_index = 0
        self.queue = Pointer(to=queue)

    def next(mut self) -> Optional[Job]:
        if self.next_index == self.end:
            return None
        var slot = self.queue[].storage.unsafe_ptr().unsafe_offset(
            self.next_index
        )
        self.next_index += 1
        return slot.unsafe_take_pointee()

    def __deinit__(deinit self):
        var base = self.queue[].storage.unsafe_ptr()
        unsafe_destroy_n(
            base.unsafe_offset(self.next_index), self.end - self.next_index
        )


def main() raises:
    var retired = ArcPointer(0)
    var queue = JobQueue(capacity=4)
    for id in range(4):
        queue.push(Job(1000 + id, retired))

    var drain = queue.drain()
    var first = drain.next()
    assert_equal(first.value().id, 1000)
    _ = drain^
    assert_equal(retired[], 3)
    _ = first^
    assert_equal(retired[], 4)

    for id in range(4):
        queue.push(Job(2000 + id, retired))
    var abandoned = queue.drain()
    forget_deinit(abandoned^)
    assert_equal(queue.length, 0)
    _ = queue^
    # The four forgotten jobs leaked: no destructor ran, and none ran twice.
    assert_equal(retired[], 4)
```

[code/06-ownership-based-resource-management/drain_leak_amplification.mojo](code/06-ownership-based-resource-management/drain_leak_amplification.mojo)

The alternative ordering, where the guard updates the length only in its
destructor, leaves the queue claiming jobs that the guard already moved out.
Forgetting that guard makes the queue's destructor run on moved-out slots.
That is a double destruction, which is undefined behavior, and safe code
(a call to `forget_deinit`) would have caused it. Unsafe code must never let
that happen.
