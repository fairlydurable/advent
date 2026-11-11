# 1. Meet safe and unsafe

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/memory/alloc.mojo, Mojo/stdlib/std/memory/memory.mojo, Mojo/stdlib/std/traits/anytype.mojo, Mojo/stdlib/std/traits/deinitable.mojo, Mojo/stdlib/std/collections/list.mojo, Mojo/stdlib/std/collections/check_bounds.mojo, Mojo/stdlib/std/builtin/debug_assert.mojo, Mojo/stdlib/std/simd.mojo, Mojo/stdlib/std/origin/__init__.mojo -->

Where Mojo draws the line between checked and unchecked code, what crosses it, and how to build safe types on unchecked foundations.

## Overview

Mojo has no `unsafe` keyword and no unsafe blocks. The line between checked
and unchecked code runs through names instead: an operation that can cause
undefined behavior carries an `unsafe_` prefix (`unsafe_offset`,
`unsafe_write`, `unsafe_take_pointee`, `unsafe_origin_cast`), takes an
`unsafe_`-prefixed keyword argument (`List(unsafe_uninit_length=)`), or sits
behind an escape hatch whose name announces it (`external_call`, `bitcast`,
`UnsafeUnion`). Everything else is safe: if it compiles and runs, it can't
read uninitialized memory, touch freed memory, or let two mutable references
to one value meet in one call.

The prefix works like a signature on a contract. Code that calls an
`unsafe_` function promises the conditions listed in that function's
`Safety:` section. The compiler can't verify the promise, and nothing marks
the calling function as unsafe in turn, so the promise has to hold for every
input that the calling function accepts.

## 1.1 How safe and unsafe interact

*Rustonomicon counterpart: How Safe and Unsafe Interact.*

### What the safe side checks

Safe code rests on four compile-time checks:

1. Initialization: no read of a value before it exists or after it moves.
2. Origins: a reference or `Pointer` names the value it came from, and that
   value can't move or die while the reference is in use.
3. Exclusivity: one call can't receive the same value through a `mut`
   argument and any other argument (section 1.2 covers the one exception).
4. Linear values: a `not Deinitable` value, such as an `Allocation`, must be
   consumed on every path.

`Pointer(to=value)` and `ptr[]` are safe. The pointer carries the origin of
`value`, and writes through it reach the original:

```mojo
# Claim: `Pointer(to=value)` and `ptr[]` are safe operations; the pointer
# carries the origin of `value`, and writes through it reach the original.
# Claim: a live pointer keeps its target alive, so ASAP destruction waits.
from std.testing import assert_equal


def main() raises:
    var pressure_kpa = 101
    var gauge = Pointer(to=pressure_kpa)
    gauge[] += 4
    assert_equal(pressure_kpa, 105)

    var station = String("north-ridge")
    var label = Pointer(to=station)
    # `station` has no direct use below, but `label` refers to it, so
    # `station` stays alive until `label`'s last use.
    assert_equal(label[], "north-ridge")
```

[code/01-safe-and-unsafe/safe_pointer_tracks_origin.mojo](code/01-safe-and-unsafe/safe_pointer_tracks_origin.mojo)

The origin also blocks a pointer from outliving a transfer of its target:

```mojo
# EXPECT-ERROR: a pointer can't outlive a transfer of the value it points to
# EXPECT-MATCH: use of uninitialized value 'station'
# Claim: once `station^` moves the value out, any pointer into the old
# binding is unusable, and the compiler reports the read.
def main():
    var station = String("north-ridge")
    var label = Pointer(to=station)
    var archived = station^
    print(label[], archived)
```

[code/01-safe-and-unsafe/pointer_after_transfer_fails.mojo](code/01-safe-and-unsafe/pointer_after_transfer_fails.mojo)

### The allocation handle closes three classic holes

`alloc` returns an `Allocation`, which bundles the owning pointer with the
`Layout` it came from. `Allocation` is `not Deinitable`, and the pointer from
`unsafe_ptr()` borrows from it. Those two facts turn three runtime hazards
into compile errors.

A double free reads a binding that `dealloc` already consumed:

```mojo
# EXPECT-ERROR: dealloc consumes the Allocation, so a second dealloc reads a moved-from binding
# EXPECT-MATCH: use of uninitialized value 'frames'
# Claim: double free is a compile-time error for an `Allocation`.
from std.memory import alloc, dealloc, Layout


def main():
    var frames = alloc(Layout[UInt8](length=4096))
    dealloc(frames^)
    dealloc(frames^)
```

[code/01-safe-and-unsafe/double_free_fails.mojo](code/01-safe-and-unsafe/double_free_fails.mojo)

A use after free reads through a pointer whose origin no longer holds a
value:

```mojo
# EXPECT-ERROR: a pointer from unsafe_ptr() borrows from its Allocation and dies with it
# EXPECT-MATCH: uninitialized value 'frames'
# Claim: reading through a pointer after `dealloc` is a compile-time error,
# because the pointer's origin is the `Allocation` itself.
from std.memory import alloc, dealloc, Layout


def main():
    var frames = alloc(Layout[UInt8](length=4096))
    var first_byte = frames.unsafe_ptr()
    first_byte.write(0x7F)
    dealloc(frames^)
    print(first_byte[])
```

[code/01-safe-and-unsafe/use_after_free_fails.mojo](code/01-safe-and-unsafe/use_after_free_fails.mojo)

A leak on an error path abandons the handle on the path where the call
raises:

```mojo
# EXPECT-ERROR: a raising call between alloc and dealloc leaves an error path that abandons the Allocation
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim: the linear-type check covers error paths, not only the happy path.
from std.memory import alloc, dealloc, Layout


def parse_header(byte_count: Int) raises -> Int:
    if byte_count < 16:
        raise Error("truncated header")
    return byte_count - 16


def main() raises:
    var packet = alloc(Layout[UInt8](length=1500))
    var payload = parse_header(len(packet))
    print("payload bytes:", payload)
    dealloc(packet^)
```

[code/01-safe-and-unsafe/leak_on_error_path_fails.mojo](code/01-safe-and-unsafe/leak_on_error_path_fails.mojo)

The fix releases the storage on both paths. Note that `assert_equal` raises
too, so any test assertion between `alloc` and `dealloc` creates the same
error path; samples in this book check values after the storage is gone.

```mojo
# Claim: releasing the allocation on both the error path and the success
# path satisfies the linear-type check.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


def parse_header(byte_count: Int) raises -> Int:
    if byte_count < 16:
        raise Error("truncated header")
    return byte_count - 16


def payload_size(packet_bytes: Int) raises -> Int:
    var packet = alloc(Layout[UInt8](length=packet_bytes))
    var payload: Int
    try:
        payload = parse_header(len(packet))
    except e:
        dealloc(packet^)
        raise e^
    dealloc(packet^)
    return payload


def main() raises:
    assert_equal(payload_size(1500), 1484)
    var rejected = False
    try:
        _ = payload_size(8)
    except:
        rejected = True
    assert_equal(rejected, True)
```

[code/01-safe-and-unsafe/leak_on_error_path_fixed.mojo](code/01-safe-and-unsafe/leak_on_error_path_fixed.mojo)

The `unsafe_ptr()` name stays honest: the borrow tracks the handle, but it
doesn't track which slots hold initialized values. That part remains your
job.

### Linear values propagate to their owners

A struct that stores an `Allocation` takes on its obligation. Without a
destructor that consumes the field, the field declaration itself is an
error:

```mojo
# EXPECT-ERROR: a struct with a linear field needs a destructor that consumes that field
# EXPECT-MATCH: non-'Deinitable' type
# Claim: holding an `Allocation` field makes the containing struct
# responsible for releasing it; without a `__deinit__` that consumes the
# field (or a `not Deinitable` declaration), the field itself is an error.
from std.memory import alloc, Allocation, Layout


struct FrameBuffer:
    var _pixels: Allocation[UInt32]

    def __init__(out self, pixel_count: Int):
        self._pixels = alloc(Layout[UInt32](length=pixel_count))


def main():
    var screen = FrameBuffer(1920 * 1080)
    print(len(screen._pixels))
```

[code/01-safe-and-unsafe/linear_field_needs_deinit_fails.mojo](code/01-safe-and-unsafe/linear_field_needs_deinit_fails.mojo)

The owner has two ways out. It can write a `__deinit__` that consumes the
field (the `BoundedStack` in section 1.3 does this), or it can stay linear
itself and expose named destructors. A method that takes `deinit self`
consumes the value, and the `else` string on the `not Deinitable`
conformance becomes the compiler's guidance to anyone who forgets:

```mojo
# Claim: a struct can stay linear instead of writing `__deinit__`: declare
# it `not Deinitable` and give it a named method that takes `deinit self`.
# Every owner must then call that method on every path.
# Claim: the `else` string on the conformance becomes the guidance in the
# compiler's message when an owner forgets.
from std.memory import alloc, dealloc, Allocation, Layout
from std.testing import assert_equal


struct FrameBuffer(
    not Deinitable else "call present() or discard() on a FrameBuffer"
):
    var _pixels: Allocation[UInt32]

    def __init__(out self, pixel_count: Int):
        self._pixels = alloc(Layout[UInt32](length=pixel_count))
        for index in range(pixel_count):
            self._pixels.unsafe_ptr().unsafe_offset(index).write(0xFF000000)

    def present(deinit self) -> UInt32:
        var corner = self._pixels.unsafe_ptr()[]
        dealloc(self._pixels^)
        return corner

    def discard(deinit self):
        dealloc(self._pixels^)


def main() raises:
    var screen = FrameBuffer(640 * 480)
    var corner = screen^.present()
    assert_equal(corner, 0xFF000000)

    var scratch = FrameBuffer(64)
    scratch^.discard()
```

[code/01-safe-and-unsafe/linear_struct_named_destructor.mojo](code/01-safe-and-unsafe/linear_struct_named_destructor.mojo)

```mojo
# EXPECT-ERROR: a linear struct that no path consumes, reported with the type's own guidance
# EXPECT-MATCH: call present\(\) or discard\(\)
# Claim: forgetting the named destructor of a `not Deinitable` struct is a
# compile error, and the message carries the type author's text.
from std.memory import alloc, dealloc, Allocation, Layout


struct FrameBuffer(
    not Deinitable else "call present() or discard() on a FrameBuffer"
):
    var _pixels: Allocation[UInt32]

    def __init__(out self, pixel_count: Int):
        self._pixels = alloc(Layout[UInt32](length=pixel_count))

    def discard(deinit self):
        dealloc(self._pixels^)


def main():
    var screen = FrameBuffer(640 * 480)
    print(len(screen._pixels))
```

[code/01-safe-and-unsafe/linear_struct_forgotten_fails.mojo](code/01-safe-and-unsafe/linear_struct_forgotten_fails.mojo)

### Unsafe code trusts types, not logic

Unchecked code may rely on the type signatures of the code it calls. It
must not rely on that code being correct. A comparison function that lies,
a `__len__` that miscounts, or a `__hash__` that changes between calls are
bugs in safe code, and safe code bugs must never turn into memory
corruption inside your unchecked code.

This binary search reads through an unchecked pointer. Its loop invariant
keeps every probe inside the span no matter what the comparison returns, so
a lying comparison produces a wrong answer, never an out-of-bounds read:

```mojo
# Claim: unsafe code may trust the types of the safe code it calls, but not
# its logic. This binary search reads through an unchecked pointer, so it
# keeps every probe inside [0, count) no matter what `precedes` answers.
# Claim: with an inconsistent comparison, the result is wrong but in bounds,
# which is a logic bug, not undefined behavior.
from std.testing import assert_equal, assert_true


def insertion_point(
    sorted_ms: Span[Int, _], target: Int, precedes: Some[def(Int, Int) -> Bool]
) -> Int:
    var data = sorted_ms.unsafe_ptr()
    var low = 0
    var high = len(sorted_ms)
    while low < high:
        var middle = low + (high - low) // 2  # low <= middle < high
        if precedes(data[unsafe_offset=middle], target):
            low = middle + 1
        else:
            high = middle
    return low


def by_value(lhs: Int, rhs: Int) -> Bool:
    return lhs < rhs


def always_yes(lhs: Int, rhs: Int) -> Bool:
    return True


def main() raises:
    var latencies_ms: List[Int] = [4, 9, 15, 22, 40]
    assert_equal(insertion_point(Span(latencies_ms), 16, by_value), 3)

    var position = insertion_point(Span(latencies_ms), 16, always_yes)
    assert_true(position >= 0 and position <= len(latencies_ms))
```

[code/01-safe-and-unsafe/distrust_caller_logic.mojo](code/01-safe-and-unsafe/distrust_caller_logic.mojo)

### Privacy is a convention

A leading underscore marks a field as internal, and nothing enforces it.
Any code that can name the struct can read and write its fields:

```mojo
# Claim: a leading underscore marks a field as internal by convention only.
# Code outside the struct can still read and write it, so a struct can't
# rely on field visibility to protect an invariant.
from std.testing import assert_equal


struct OdometerKm:
    var _reading: Int

    def __init__(out self):
        self._reading = 0

    def advance(mut self, distance: Int):
        if distance > 0:
            self._reading += distance


def main() raises:
    var odometer = OdometerKm()
    odometer.advance(120)
    odometer._reading = -40  # Compiles: nothing enforces the underscore.
    assert_equal(odometer._reading, -40)
```

[code/01-safe-and-unsafe/privacy_is_convention.mojo](code/01-safe-and-unsafe/privacy_is_convention.mojo)

So a struct can't rely on visibility to protect the invariant that its
unchecked code depends on. Two habits make up for it: keep the invariant
in as few fields as possible, and give any method that can break it an
`unsafe_` name with a `Safety:` note. Section 1.3 shows both.

## 1.2 What unsafe can do

*Rustonomicon counterpart: What Unsafe Can Do.*

### The unchecked operations

These are the operations that can produce undefined behavior when misused:

- Dereferencing a `Pointer` that came from an allocation, an offset, a cast,
  or foreign code (`ptr[]`, `ptr[unsafe_offset=index]`, `unsafe_load`,
  `unsafe_store`), where the compiler can't see what lives at the address.
- Pointer arithmetic that leaves the allocation (`unsafe_offset`) and then
  dereferences.
- Initializing, moving out of, and destroying pointees by hand
  (`unsafe_write`, `unsafe_take_pointee`, `unsafe_deinit_pointee`,
  `unsafe_destroy_n`, `MaybeUninit.unsafe_assume_init`).
- Changing a pointer's type, mutability, origin, or address space
  (`unsafe_bitcast`, `unsafe_mut_cast`, `unsafe_origin_cast`,
  `as_unsafe_any_origin`, `unsafe_address_space_cast`).
- Reinterpreting bits (`bitcast`, `UnsafeUnion.unsafe_get`).
- Calling foreign functions (`external_call`), where the compiler trusts the
  declared signature.
- Turning off checks at build time with `-D ASSERT=none` (or demoting them
  with `-D ASSERT=warn`), which lets the bounds checks that `List` and other
  collections perform stop guarding the read.

This sample uses the main ones correctly. Each step leaves memory in a state
that the next step's `Safety:` contract requires:

```mojo
# Claim: the operations that can cause undefined behavior carry an `unsafe_`
# prefix (or live behind `external_call`, `bitcast`, and similar escape
# hatches). This sample uses each one correctly.
from std.ffi import external_call
from std.memory import alloc, dealloc, bitcast, Layout
from std.testing import assert_equal


def main() raises:
    var slots = alloc(Layout[String](length=2))
    var base = slots.unsafe_ptr()

    # Initialize uninitialized memory.
    base.unsafe_write(String("pump-a"))
    base.unsafe_offset(1).unsafe_write(String("pump-b"))

    # Move a value out, leaving its slot uninitialized.
    var first = base.unsafe_take_pointee()

    # Destroy a value in place.
    base.unsafe_offset(1).unsafe_deinit_pointee()

    # Both slots are now uninitialized, so releasing the storage is sound.
    dealloc(slots^)
    # Asserts raise, and a raise between `alloc` and `dealloc` would abandon
    # the allocation, so the checks wait until the storage is gone.
    assert_equal(first, "pump-a")

    # Reinterpret bits.
    var one_bits = bitcast[DType.uint32](Float32(1.0))
    assert_equal(one_bits, 0x3F800000)

    # Call foreign code. The compiler trusts the declared signature.
    var magnitude = external_call["abs", Int32](Int32(-17))
    assert_equal(magnitude, 17)
```

[code/01-safe-and-unsafe/unsafe_operations_tour.mojo](code/01-safe-and-unsafe/unsafe_operations_tour.mojo)

### Safe and unsafe write

`Pointer` has two families of writers, and the difference teaches the whole
model. `write()` is safe, and accepts only trivially deinitializable types.
For those, overwriting a live value can't skip a destructor, because there
is none:

```mojo
# Claim: `Pointer.write()` is safe for trivially deinitializable types, so
# writing over a live `Int` twice is fine: there is no destructor to skip.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


def main() raises:
    var slot = alloc(Layout[Int].single())
    var cell = slot.unsafe_ptr()
    cell.write(1450)
    cell.write(1475)
    var stored = cell[]
    dealloc(slot^)
    assert_equal(stored, 1475)
```

[code/01-safe-and-unsafe/safe_write_overwrites_trivial.mojo](code/01-safe-and-unsafe/safe_write_overwrites_trivial.mojo)

For a type with a destructor, `write()` doesn't compile, and you must choose
`unsafe_write()`:

```mojo
# EXPECT-ERROR: the safe write() only accepts types with no destructor, since it may overwrite a live value
# EXPECT-MATCH: invalid call to 'write'
# Claim: `Pointer.write()` refuses `String`, whose overwritten value would
# leak; `unsafe_write()` is the spelling that accepts that responsibility.
from std.memory import alloc, dealloc, Layout


def main():
    var slot = alloc(Layout[String].single())
    slot.unsafe_ptr().write(String("calibrated"))
    slot.unsafe_ptr().unsafe_deinit_pointee()
    dealloc(slot^)
```

[code/01-safe-and-unsafe/safe_write_needs_trivial_type_fails.mojo](code/01-safe-and-unsafe/safe_write_needs_trivial_type_fails.mojo)

`unsafe_write()` assumes the slot is empty. Writing over a live value never
runs that value's destructor. Here the overwritten lease holds a share of a
reference count, and the count proves the share never comes back:

```mojo
# Claim: `unsafe_write()` assumes the slot holds no live value. Writing over
# a live value never runs the old value's destructor, so the old value leaks.
# A leak is not undefined behavior; it is a resource the program never
# releases.
# The lease holds a reference-counted share of a budget, so the count shows
# how many leases are still alive.
from std.memory import alloc, dealloc, ArcPointer, Layout
from std.testing import assert_equal


@fieldwise_init
struct Lease(Movable):
    var budget: ArcPointer[Int]


def main() raises:
    var budget = ArcPointer(5000)
    var slot = alloc(Layout[Lease].single())
    var cell = slot.unsafe_ptr()

    cell.unsafe_write(Lease(budget.copy()))
    cell.unsafe_write(Lease(budget.copy()))  # The first lease never ends.
    cell.unsafe_deinit_pointee()
    dealloc(slot^)

    # One share for `budget`, one for the leaked lease.
    assert_equal(budget.count(), 2)
```

[code/01-safe-and-unsafe/unsafe_write_skips_old_destructor.mojo](code/01-safe-and-unsafe/unsafe_write_skips_old_destructor.mojo)

### What safe code may still do

Safety in Mojo means memory safety. Several outcomes that feel wrong are
defined and allowed in safe code.

Leaking is safe. `forget_deinit` takes a value and skips its destructor and
the destructors of all its fields. It needs no `unsafe_` prefix, because
Mojo can't promise that destructors run in general (a program can abort, or
store a value in a cycle of reference counts):

```mojo
# Claim: `forget_deinit` is a safe function. Skipping a destructor can leak,
# but leaking never breaks memory safety, so no `unsafe_` prefix applies.
# Claim: it skips the destructors of the value's fields too.
from std.memory import forget_deinit, ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Replicas(Movable):
    var primary: ArcPointer[String]
    var backup: ArcPointer[String]


def main() raises:
    var config = ArcPointer(String("region=us-west"))

    var kept = Replicas(config.copy(), config.copy())
    assert_equal(config.count(), 3)
    _ = kept^  # Normal destruction: both fields release their share.
    assert_equal(config.count(), 1)

    var dropped = Replicas(config.copy(), config.copy())
    forget_deinit(dropped^)
    assert_equal(config.count(), 3)  # Neither field released its share.
```

[code/01-safe-and-unsafe/forget_deinit_is_safe.mojo](code/01-safe-and-unsafe/forget_deinit_is_safe.mojo)

Integer arithmetic has fully defined results. Overflow wraps in two's
complement at every width, and integer division or remainder by zero returns
0. Neither traps:

```mojo
# Claim: integer overflow wraps in two's complement, at every width.
# Claim: integer division and remainder by zero return 0 instead of trapping.
# Claim: `//` floors and `%` takes the sign of the divisor.
from std.testing import assert_equal


def main() raises:
    assert_equal(Int.MAX + 1, Int.MIN)
    var level: UInt8 = 250
    assert_equal(level + 10, 4)
    var signed_level: Int8 = 127
    assert_equal(signed_level + 1, -128)

    var shards = 0
    assert_equal(4096 // shards, 0)
    assert_equal(4096 % shards, 0)

    assert_equal(-7 // 2, -4)
    assert_equal(-7 % 2, 1)
```

[code/01-safe-and-unsafe/integer_rules_are_defined.mojo](code/01-safe-and-unsafe/integer_rules_are_defined.mojo)

Aborting is safe. With the default assertion level, `List` checks every
index on CPU and aborts the program on an out-of-range index, before any
read happens:

```mojo
# EXPECT-EXIT: nonzero
# Claim: `List` indexing checks bounds on CPU at the default assertion
# level, and an out-of-range index aborts the program instead of reading
# past the end. Building with `-D ASSERT=none` removes this check.
def main():
    var readings: List[Int] = [12, 15, 19]
    var index = len(readings)
    print(readings[index])
```

[code/01-safe-and-unsafe/bounds_check_aborts.mojo](code/01-safe-and-unsafe/bounds_check_aborts.mojo)

Build with `-D ASSERT=none` and that check disappears, and the same index
becomes undefined behavior. `-D ASSERT=warn` has the same effect at run time:
it prints the failed check and keeps going. Treat both as unsafe build
modes, not speed or logging settings.

### Exclusivity lives at call boundaries

The exclusivity check applies to the arguments of one call. A value can't
arrive through a `mut` argument and through any other argument of the same
call:

```mojo
# EXPECT-ERROR: one value passed to two mut arguments of the same call
# EXPECT-MATCH: aliasing values passed mutably
# Claim: a call can't receive the same value through two `mut` arguments.
def settle(mut payer: Int, mut payee: Int, amount: Int):
    payer -= amount
    payee += amount


def main():
    var balance_cents = 10_000
    settle(balance_cents, balance_cents, 2_500)
```

[code/01-safe-and-unsafe/exclusive_mut_arguments_fails.mojo](code/01-safe-and-unsafe/exclusive_mut_arguments_fails.mojo)

```mojo
# EXPECT-ERROR: one String passed to a mut argument and an imm argument of the same call
# EXPECT-MATCH: passed immutably
# Claim: a `mut` argument excludes every other reference to the same value
# in that call, including an immutable one.
def append_twice(mut journal: String, imm entry: String):
    journal += entry
    journal += entry


def main():
    var journal = String("boot;")
    append_twice(journal, journal)
```

[code/01-safe-and-unsafe/exclusive_mut_and_imm_fails.mojo](code/01-safe-and-unsafe/exclusive_mut_and_imm_fails.mojo)

There is one deliberate exception. An `imm` argument of a trivial
register-passable type, such as `Int`, arrives as a copy, so it can't
observe the `mut` argument's writes, and the call is legal:

```mojo
# Claim: an `imm` argument of a trivial register-passable type such as `Int`
# arrives as a copy, so passing one value to both a `mut` and an `imm`
# argument is legal and the `imm` side sees the value from the call site.
from std.testing import assert_equal


def add_interest(mut balance: Int, imm basis: Int):
    balance += basis // 10
    balance += basis // 10


def main() raises:
    var balance = 1000
    add_interest(balance, balance)
    assert_equal(balance, 1200)  # Both steps used the original 1000.
```

[code/01-safe-and-unsafe/trivial_imm_argument_is_a_copy.mojo](code/01-safe-and-unsafe/trivial_imm_argument_is_a_copy.mojo)

`Pointer` values don't take part in exclusivity at all. Two mutable
pointers to one value, plus writes through the owning binding, all coexist.
The pointers share one tracked origin, and the compiler keeps the value
alive while any of them is in use:

```mojo
# Claim: exclusivity checking applies to arguments of a call. Holding two
# mutable `Pointer`s to one value, or writing through the owning binding
# while a pointer is live, is legal.
from std.testing import assert_equal


def main() raises:
    var rpm = 900
    var governor = Pointer(to=rpm)
    var throttle = Pointer(to=rpm)
    governor[] += 100
    throttle[] += 50
    rpm += 25
    assert_equal(governor[], 1075)
    assert_equal(throttle[], 1075)
```

[code/01-safe-and-unsafe/pointers_are_not_borrows.mojo](code/01-safe-and-unsafe/pointers_are_not_borrows.mojo)

## 1.3 Working with unsafe

*Rustonomicon counterpart: Working with Unsafe.*

### Unsafety leaks across the whole type

An `unsafe_` call is sound only if the state around it holds. That state
lives in fields that safe methods also touch, so a change to a safe method
can break unchecked code three methods away. The unit of soundness is the
type, not the line.

`BoundedStack` owns raw storage and keeps one invariant: `_count` never
exceeds the capacity, slots below `_count` hold live values, and slots at or
above it don't. `push`, `pop`, and `__deinit__` all depend on it.
`unsafe_set_count` is the one method that can break it, and its name and
docstring say so:

```mojo
# Claim: a struct that owns raw storage keeps one invariant
# (`_count <= capacity`, and slots below `_count` hold live values), and
# every method relies on it. The checked methods are safe because they
# uphold it; `unsafe_set_count` is the one door that can break it, and its
# name says so.
# Claim: `__deinit__` destroys exactly the live elements, then releases the
# storage, so no element leaks and no element dies twice.
from std.memory import alloc, dealloc, unsafe_destroy_n, Allocation, ArcPointer, Layout
from std.testing import assert_equal, assert_false


struct BoundedStack[T: Movable & Deinitable](Sized):
    var _storage: Allocation[Self.T]
    var _count: Int

    def __init__(out self, capacity: Int):
        self._storage = alloc(Layout[Self.T](length=capacity))
        self._count = 0

    def __deinit__(deinit self):
        unsafe_destroy_n(self._storage.unsafe_ptr(), self._count)
        dealloc(self._storage^)

    def capacity(self) -> Int:
        return len(self._storage)

    def __len__(self) -> Int:
        return self._count

    def push(mut self, var value: Self.T) -> Bool:
        if self._count == self.capacity():
            return False  # `value` dies here, at its last use.
        self._storage.unsafe_ptr().unsafe_offset(self._count).unsafe_write(
            value^
        )
        self._count += 1
        return True

    def pop(mut self) -> Optional[Self.T]:
        if self._count == 0:
            return None
        self._count -= 1
        return self._storage.unsafe_ptr().unsafe_offset(
            self._count
        ).unsafe_take_pointee()

    def unsafe_set_count(mut self, count: Int):
        """Sets the element count without initializing or destroying.

        Safety: every slot below `count` must hold a live value, and every
        slot at or above it must not.
        """
        self._count = count


def main() raises:
    var config = ArcPointer(String("ttl=30"))
    var stack = BoundedStack[ArcPointer[String]](capacity=2)
    _ = stack.push(config.copy())
    _ = stack.push(config.copy())
    var accepted = stack.push(config.copy())
    assert_false(accepted)  # Full: the rejected share released at once.
    assert_equal(config.count(), 3)

    var top = stack.pop()
    assert_equal(len(stack), 1)
    _ = top^
    assert_equal(config.count(), 2)

    _ = stack^  # Destroys the one live element, then frees storage.
    assert_equal(config.count(), 1)
```

[code/01-safe-and-unsafe/bounded_stack_invariant.mojo](code/01-safe-and-unsafe/bounded_stack_invariant.mojo)

Read `__deinit__` closely. It destroys exactly `_count` elements and then
consumes the `Allocation` field, which is the only way a struct holding a
linear field can be `Deinitable`. If any method, safe or not, left
`_count` above the last live slot, the destructor would destroy values that
don't exist. This snippet is undefined
behavior and appears here only to show the shape of the bug:

```mojo
# Undefined behavior: slot 1 holds no value, and __deinit__ destroys it.
var stack = BoundedStack[ArcPointer[String]](capacity=2)
_ = stack.push(ArcPointer(String("ttl=30")))
stack.unsafe_set_count(2)
```

### Origins stop escapes, and casts switch them off

A function can't return a pointer to its own local under an origin the
caller picks. The local's origin is a different origin, and it doesn't
convert:

```mojo
# EXPECT-ERROR: a pointer to a local can't convert to a caller-chosen origin
# EXPECT-MATCH: cannot implicitly convert 'Pointer\[Int, origin_of\(local_reading\)\]'
# Claim: a function can't return a pointer to its own local under an origin
# the caller picked; the local's origin doesn't convert to it.
def latest_reading[origin: MutOrigin]() -> Pointer[Int, origin]:
    var local_reading = 512
    return Pointer(to=local_reading)


def main():
    pass
```

[code/01-safe-and-unsafe/pointer_cannot_escape_frame_fails.mojo](code/01-safe-and-unsafe/pointer_cannot_escape_frame_fails.mojo)

The exclusivity check treats every element of a `List` as part of the
list's origin, so two element references can't meet in one call:

```mojo
# EXPECT-ERROR: two element references from one List passed to mut arguments of one call
# EXPECT-MATCH: aliasing values passed mutably
# Claim: the exclusivity check treats every element of a List as part of
# one origin, so `swap` can't take two of its elements at once.
def main():
    var queue: List[String] = ["ingest", "transform", "publish"]
    swap(queue[0], queue[2])
```

[code/01-safe-and-unsafe/swap_two_elements_fails.mojo](code/01-safe-and-unsafe/swap_two_elements_fails.mojo)

The safe answer moves the operation inside the container, as
`swap_elements` does. Inside a container's own implementation, the
standard library takes the other road: it casts the element pointer to
`MutUntrackedOrigin`, an origin the checker doesn't track, and then owns the
proof that the accesses don't conflict. `List.insert` and `List.pop` both
do this. So can you, inside a type whose invariants you control:

```mojo
# Claim: two element references into one List can't both go to `mut`
# arguments of one call; the safe answer is a method that does the work
# inside the container (`swap_elements`).
# Claim: inside a container's own implementation, casting the element
# pointer to `MutUntrackedOrigin` steps outside exclusivity checking; the
# code then owns the proof that the accesses don't conflict.
from std.testing import assert_equal


def rotate_left_by_one(mut queue: List[String]):
    if len(queue) < 2:
        return
    var data = queue.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    # Each step swaps two distinct, initialized slots.
    for index in range(len(queue) - 1):
        data.unsafe_offset(index).swap_pointees(data.unsafe_offset(index + 1))


def main() raises:
    var queue: List[String] = ["ingest", "transform", "publish"]
    queue.swap_elements(0, 2)
    assert_equal(queue[0], "publish")
    assert_equal(queue[2], "ingest")

    rotate_left_by_one(queue)
    assert_equal(queue[0], "transform")
    assert_equal(queue[1], "ingest")
    assert_equal(queue[2], "publish")
```

[code/01-safe-and-unsafe/untracked_origin_for_overlap.mojo](code/01-safe-and-unsafe/untracked_origin_for_overlap.mojo)

Avoid `MutAnyOrigin` and `UnsafeAnyOrigin` as a way out. A pointer with an
any-origin claims it might point into every live value, which extends unrelated
lifetimes, hides unused-value warnings, and switches off exclusivity
checking. It also lets a dangling pointer through. This snippet compiles,
and calling it is undefined behavior:

```mojo
# Undefined behavior: the pointer outlives `local`.
def latest_reading() -> Pointer[Int, MutAnyOrigin]:
    var local = 512
    return Pointer(to=local)
```

The checklist for any unchecked code you write:

1. Write the invariant down, in the struct's docstring, before the code.
2. Name every method that can break it with an `unsafe_` prefix and a
   `Safety:` section.
3. Keep `Allocation` and other linear handles as fields, so the compiler
   still forces the release on every path.
4. Prefer `MutUntrackedOrigin` casts, scoped to one method, over
   any-origins.
5. Assume every safe function you call, including your caller's trait
   implementations, can return a wrong answer.
