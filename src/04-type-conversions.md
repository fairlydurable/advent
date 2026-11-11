# 4. Type conversions

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/memory/unsafe.mojo, Mojo/stdlib/std/builtin/rebind.mojo, Mojo/stdlib/std/ffi/unsafe_union.mojo, Mojo/stdlib/std/simd.mojo, Mojo/stdlib/std/memory/arc_pointer.mojo, Mojo/stdlib/std/memory/owned_pointer.mojo, Mojo/stdlib/std/sys/info.mojo -->

Implicit conversions, method lookup through pointers, numeric and pointer casts, and bit-level reinterpretation in Mojo.

At the level of bits, a value of one type can always pass for a value of
another. Mojo restricts which reinterpretations happen on their own, which
ones need an explicit call, and which ones need you to vouch for the result.
This chapter climbs that ladder: conversions the compiler inserts, then
conversions you request, then reinterpretations the compiler can't check.

Each code block below omits its file's header comment, which restates the
claims the file tests. Files whose names end in `_fails.mojo` don't compile,
on purpose.

## 4.1 Coercions

*Rustonomicon counterpart: Coercions.*

Mojo inserts a conversion without being asked in three situations: a literal
meets a typed context, a constructor carries `@implicit`, or a pointer drops
mutability. Everything else needs a call you can see.

### `@implicit` constructors

A single-argument constructor marked `@implicit` lets the compiler convert
at an argument, at an annotated `var`, or at a `return`. The type author
opts in, one constructor at a time.

```mojo
from std.testing import assert_equal


struct Seconds(ImplicitlyCopyable):
    var count: Int

    @implicit
    def __init__(out self, count: Int):
        self.count = count


struct Millis(ImplicitlyCopyable):
    var count: Int

    @implicit
    def __init__(out self, seconds: Seconds):
        self.count = seconds.count * 1000


def timeout_budget(duration: Millis) -> Int:
    return duration.count


def default_backoff() -> Seconds:
    return 30  # converts through Seconds.__init__(count:)


def main() raises:
    assert_equal(timeout_budget(Seconds(3)), 3000)
    var grace: Seconds = 45
    assert_equal(grace.count, 45)
    assert_equal(default_backoff().count, 30)
```

[code/04-type-conversions/implicit_constructor.mojo](code/04-type-conversions/implicit_constructor.mojo)

Conversions don't chain. The compiler applies at most one implicit
constructor per value, so `Int` to `Seconds` works and `Seconds` to `Millis`
works, but `Int` to `Millis` through `Seconds` does not. That keeps the set
of conversions at any call site small enough to reason about.

```mojo
struct Seconds(ImplicitlyCopyable):
    var count: Int

    @implicit
    def __init__(out self, count: Int):
        self.count = count


struct Millis(ImplicitlyCopyable):
    var count: Int

    @implicit
    def __init__(out self, seconds: Seconds):
        self.count = seconds.count * 1000


def timeout_budget(duration: Millis) -> Int:
    return duration.count


def main():
    print(timeout_budget(5))
```

[code/04-type-conversions/implicit_chain_fails.mojo](code/04-type-conversions/implicit_chain_fails.mojo)

### Literals take their type from context

Integer and floating-point literals have their own compile-time types, and
they materialize as whatever numeric type the context asks for. An integer
literal can become a `Float64`, and a scalar literal splats across all lanes
of a `SIMD` vector. String types follow the same pattern through implicit
constructors: a string literal becomes an owned `String`, and a `String`
lends itself out as a `StringSpan`.

```mojo
from std.testing import assert_equal


def label_bytes(label: StringSpan) -> Int:
    return label.byte_length()


def owned_bytes(label: String) -> Int:
    return label.byte_length()


def main() raises:
    var ratio: Float64 = 3
    assert_equal(ratio, 3.0)
    var mask: SIMD[DType.uint8, 4] = 7
    assert_equal(mask, SIMD[DType.uint8, 4](7, 7, 7, 7))
    var device = String("nvme0n1")
    assert_equal(label_bytes(device), 7)
    assert_equal(owned_bytes("eth0"), 4)
```

[code/04-type-conversions/literal_adaptation.mojo](code/04-type-conversions/literal_adaptation.mojo)

A literal that doesn't fit its target type still compiles. The value keeps
only its low bits, with two's complement wrapping, and the compiler issues no
diagnostic. This applies to `comptime` declarations as well, so range-check
literals that come from specifications.

```mojo
from std.testing import assert_equal


def main() raises:
    var level: UInt8 = 300  # 300 - 256
    assert_equal(level, 44)
    var offset: Int8 = 200  # 200 - 256
    assert_equal(offset, -56)
    comptime ceiling: UInt8 = 256
    assert_equal(ceiling, 0)
```

[code/04-type-conversions/literal_overflow_wraps.mojo](code/04-type-conversions/literal_overflow_wraps.mojo)

Values behave differently from literals. A binding of one numeric type never
converts implicitly to another; you write the constructor call.

```mojo
def main():
    var count = 7
    var ratio: Float64 = count
    print(ratio)
```

[code/04-type-conversions/no_implicit_numeric_fails.mojo](code/04-type-conversions/no_implicit_numeric_fails.mojo)

### Pointer mutability

A mutable `Pointer` converts implicitly to an immutable one, so you can pass
it wherever the callee only reads. `as_imm()` performs the same conversion
explicitly.

```mojo
from std.testing import assert_equal


def peek(reading: ImmPointer[Int, _]) -> Int:
    return reading[]


def main() raises:
    var pressure = 5500
    var gauge = Pointer(to=pressure)
    gauge[] += 100
    assert_equal(peek(gauge), 5600)
    assert_equal(peek(gauge.as_imm()), 5600)
```

[code/04-type-conversions/pointer_mut_to_imm.mojo](code/04-type-conversions/pointer_mut_to_imm.mojo)

The conversion runs one way only. Regaining mutability requires
`unsafe_mut_cast`, and the compiler can't check that a mutable reference was
ever valid there.

```mojo
def bump(target: MutPointer[Int, _]):
    target[] += 1


def main():
    var pressure = 5500
    var reader = Pointer(to=pressure).as_imm()
    bump(reader)
```

[code/04-type-conversions/pointer_imm_to_mut_fails.mojo](code/04-type-conversions/pointer_imm_to_mut_fails.mojo)

### `Some[Trait]`

`Some[Trait]` in an argument position accepts any type that conforms to the
trait. This isn't a conversion to a common runtime representation. Each call
site instantiates the function for its argument's concrete type, so no
boxing or dynamic dispatch takes place.

```mojo
from std.testing import assert_equal


def render(value: Some[Writable]) -> String:
    return String(value)


def main() raises:
    assert_equal(render(5500), "5500")
    assert_equal(render("valve"), "valve")
    assert_equal(render(Float32(0.5)), "0.5")
```

[code/04-type-conversions/some_trait_parameter.mojo](code/04-type-conversions/some_trait_parameter.mojo)

## 4.2 The dot operator

*Rustonomicon counterpart: The dot operator.*

`value.name` looks up `name` on the static type of `value` and nowhere else.
Mojo doesn't search through pointers or smart pointers to find a matching
method. On a `Pointer[String, _]`, the dot finds `Pointer` methods, and
`byte_length` isn't one of them.

```mojo
def main():
    var hostname = String("db-primary")
    var target = Pointer(to=hostname)
    print(target.byte_length())
```

[code/04-type-conversions/pointer_no_auto_deref_fails.mojo](code/04-type-conversions/pointer_no_auto_deref_fails.mojo)

`[]` dereferences. On `Pointer`, `OwnedPointer`, and `ArcPointer`, it yields
a reference to the pointee, and the dot then works on that reference. Each
level of indirection needs its own `[]`, so a pointer to a pointer reads as
`handle[][]`. The explicit dereference keeps every indirection visible at the
call site.

```mojo
from std.memory import OwnedPointer, ArcPointer
from std.testing import assert_equal, assert_true


def main() raises:
    var hostname = String("db-primary")
    var target = Pointer(to=hostname)
    assert_equal(target[].byte_length(), 10)

    var handle = Pointer(to=target)
    handle[][] += "-east"
    assert_equal(hostname, "db-primary-east")

    var boxed = OwnedPointer(String("replica"))
    assert_equal(boxed[].byte_length(), 7)

    var shared = ArcPointer(String("cache"))
    var second_owner = shared
    assert_equal(shared.count(), 2)
    assert_true(shared.ptr() == second_owner.ptr())
```

[code/04-type-conversions/explicit_deref.mojo](code/04-type-conversions/explicit_deref.mojo)

### What the receiver convention means

The convention on `self` decides what a method call needs from its receiver:

| Receiver | The call needs | Effect on the caller's value |
|---|---|---|
| `self` (read) | any value | none |
| `mut self` | a mutable place | changes it in place |
| `ref self` | any value | mutability follows the caller |
| `var self` | an owned value | consumes it, or a copy of it |
| `deinit self` | an owned value | ends it; `__deinit__` doesn't run |

A `ref self` method returns a reference whose mutability tracks the caller's
access. Through a mutable binding, you can assign through it; through a
`read` argument, you can't. The return annotation names where the
reference really points. Here it points into the list's heap storage, which
`ref[self.readings[0]]` names; that origin differs from the origin of the
`readings` field itself.

```mojo
from std.testing import assert_equal


struct Recorder(Movable):
    var name: String
    var readings: List[Int]

    def __init__(out self, name: String):
        self.name = name
        self.readings = []

    def latest(ref self) -> ref[self.readings[0]] Int:
        return self.readings[len(self.readings) - 1]

    def finish(deinit self) -> List[Int]:
        return self.readings^


def peek(recorder: Recorder) -> Int:
    return recorder.latest()


def main() raises:
    var recorder = Recorder("inlet")
    recorder.readings.append(5500)
    recorder.latest() += 25  # mutable binding, so the reference is mutable
    assert_equal(peek(recorder), 5525)
    var samples = recorder^.finish()
    assert_equal(len(samples), 1)
```

[code/04-type-conversions/ref_self_field_origin.mojo](code/04-type-conversions/ref_self_field_origin.mojo)

Naming the field instead of its element is a compile error. The list
element and the `List` struct live in different places, and a reference must
carry the origin of the place it actually refers to.

```mojo
struct Recorder(Movable):
    var readings: List[Int]

    def __init__(out self):
        self.readings = [5500]

    def latest(ref self) -> ref[self.readings] Int:
        return self.readings[len(self.readings) - 1]


def main():
    var recorder = Recorder()
    print(recorder.latest())
```

[code/04-type-conversions/ref_self_whole_origin_fails.mojo](code/04-type-conversions/ref_self_whole_origin_fails.mojo)

A `mut self` method writes back into the receiver, so it needs a place to
write to. A temporary has none, and the call doesn't compile.

```mojo
@fieldwise_init
struct RetryBudget(Movable):
    var remaining: Int

    def spend(mut self):
        self.remaining -= 1


def main():
    RetryBudget(3).spend()
```

[code/04-type-conversions/mutating_method_on_rvalue_fails.mojo](code/04-type-conversions/mutating_method_on_rvalue_fails.mojo)

A `var self` method takes ownership of the receiver. For a type that isn't
`ImplicitlyCopyable`, the call site has to give the value up with
`binding^.method()`. For an implicitly copyable type, the method receives a
copy and the caller keeps the original.

```mojo
struct Session(Movable):
    var token: String

    def __init__(out self, token: String):
        self.token = token

    def close(var self) -> String:
        return self.token


def main():
    var session = Session("a91f")
    print(session.close())
```

[code/04-type-conversions/var_self_needs_transfer_fails.mojo](code/04-type-conversions/var_self_needs_transfer_fails.mojo)

```mojo
from std.testing import assert_equal


@fieldwise_init
struct RetryBudget(ImplicitlyCopyable):
    var remaining: Int

    def drain(var self) -> Int:
        self.remaining = 0
        return self.remaining


def main() raises:
    var budget = RetryBudget(3)
    assert_equal(budget.drain(), 0)
    assert_equal(budget.remaining, 3)
```

[code/04-type-conversions/var_self_copies.mojo](code/04-type-conversions/var_self_copies.mojo)

A method can exist for only some instantiations of a generic type. A `where`
clause on the method states the condition. Lookup still finds the method on
other instantiations, then the `where` clause rejects the call.

```mojo
struct Probe[T: AnyType]:
    var hits: Int

    def __init__(out self):
        self.hits = 0

    def describe(self) -> String where conforms_to(Self.T, Writable):
        return "writable payload"


struct RawFrame:
    var bytes: Int


def main():
    var probe = Probe[RawFrame]()
    print(probe.describe())
```

[code/04-type-conversions/where_method_fails.mojo](code/04-type-conversions/where_method_fails.mojo)

## 4.3 Casts

*Rustonomicon counterpart: Casts.*

Mojo has no cast operator. Every value conversion is a constructor call,
such as `UInt8(count)` or `Int(ratio)`, or a method such as `SIMD.cast`.
Each one has defined behavior for every in-range input, and the integer
conversions define out-of-range behavior too.

### Numeric construction

- Integer to narrower integer keeps the low bits (two's complement wrap). It
  never saturates and never traps.
- Signed to unsigned reinterprets the bits, so `UInt8(-1)` is `255`.
- Float to integer truncates toward zero, for negative values as well as
  positive ones.

```mojo
from std.testing import assert_equal


def main() raises:
    var sample_count = 300
    assert_equal(UInt8(sample_count), 44)
    assert_equal(Int8(200), -56)
    var sentinel = -1
    assert_equal(UInt8(sentinel), 255)
    assert_equal(UInt64(sentinel), 18446744073709551615)
    assert_equal(Int(Float64(3.99)), 3)
    assert_equal(Int(Float64(-3.99)), -3)  # toward zero, not down
```

[code/04-type-conversions/numeric_construction.mojo](code/04-type-conversions/numeric_construction.mojo)

`SIMD.cast` applies the same rules to every lane. Float narrowing rounds to
the nearest representable value, so a `Float64` that goes through `Float32`
can come back different.

```mojo
from std.testing import assert_equal, assert_true


def main() raises:
    var offsets = SIMD[DType.int32, 4](255, 256, -1, 1000)
    assert_equal(offsets.cast[DType.uint8](), SIMD[DType.uint8, 4](255, 0, 255, 232))

    var gains = SIMD[DType.float32, 4](1.5, -2.5, 100.9, 0.2)
    assert_equal(gains.cast[DType.int32](), SIMD[DType.int32, 4](1, -2, 100, 0))

    var precise = Float64(123456789.123456789)
    var narrowed = Float64(Float32(precise))
    assert_equal(narrowed, 123456792.0)
    assert_true(narrowed != precise)
```

[code/04-type-conversions/simd_cast.mojo](code/04-type-conversions/simd_cast.mojo)

The stdlib defines no result for a float outside the target integer type's
range, such as `-2.5` or `300.7` cast to `UInt8`. Treat that case as
undefined behavior and clamp first. After `clamp`, every lane converts to a
defined value.

```mojo
from std.testing import assert_equal


def main() raises:
    var brightness = SIMD[DType.float32, 4](-12.0, 0.4, 254.6, 300.7)
    var clamped = brightness.clamp(0.0, 255.0)
    assert_equal(clamped.cast[DType.uint8](), SIMD[DType.uint8, 4](0, 0, 254, 255))
```

[code/04-type-conversions/clamp_before_float_cast.mojo](code/04-type-conversions/clamp_before_float_cast.mojo)

### Pointers and addresses

`Int(pointer)` produces the address. `Pointer(unsafe_from_address=)` goes
the other way and builds a pointer from an integer. The rebuilt pointer
carries whatever origin you write in its type. The compiler takes that origin
on faith, so you vouch that the target lives as long as the origin claims.
Pointer arithmetic counts in elements: `unsafe_offset(1)` advances the
address by `size_of[T]()` bytes.

```mojo
from std.sys import size_of
from std.testing import assert_equal


def main() raises:
    var pressure = 5500
    var gauge = Pointer(to=pressure)
    var address = Int(gauge)
    var rebuilt = Pointer[Int, origin_of(pressure)](unsafe_from_address=address)
    rebuilt[] += 1
    assert_equal(pressure, 5501)
    assert_equal(Int(gauge.unsafe_offset(1)) - address, size_of[Int]())
```

[code/04-type-conversions/pointer_address_roundtrip.mojo](code/04-type-conversions/pointer_address_roundtrip.mojo)

`Pointer` has no null value. A literal zero address fails at compile time.

```mojo
def main():
    var device = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=0)
    print(Int(device))
```

[code/04-type-conversions/null_address_fails.mojo](code/04-type-conversions/null_address_fails.mojo)

Use `Optional[Pointer[...]]` for a pointer that may be absent. It takes no
more space than a bare `Pointer`, because the null address serves as the
`None` niche.

```mojo
from std.sys import size_of
from std.testing import assert_equal, assert_true


def main() raises:
    var pressure = 5500
    comptime GaugePointer = Pointer[Int, origin_of(pressure)]
    assert_equal(size_of[Optional[GaugePointer]](), size_of[GaugePointer]())
    var missing: Optional[GaugePointer] = None
    assert_true(not missing)
    var present: Optional[GaugePointer] = Pointer(to=pressure)
    assert_equal(present.value()[], 5500)
```

[code/04-type-conversions/optional_pointer_niche.mojo](code/04-type-conversions/optional_pointer_niche.mojo)

## 4.4 Transmutes

*Rustonomicon counterpart: Transmutes.*

A transmute keeps the bits and changes the type. Mojo splits that job by
what the compiler can still check.

### `bitcast` for SIMD values

`bitcast` from `std.memory` reinterprets a `SIMD` value as another dtype with
the same total width. No numeric conversion happens, and a round trip
restores the original bits exactly.

```mojo
from std.memory import bitcast
from std.testing import assert_equal


def main() raises:
    var gain = Float32(1.0)
    var bits = bitcast[DType.uint32](gain)
    assert_equal(bits, 0x3F800000)  # sign 0, exponent 127, mantissa 0
    var negative = bitcast[DType.uint32](Float32(-0.0))
    assert_equal(negative, 0x80000000)  # only the sign bit
    assert_equal(bitcast[DType.float32](bits), gain)
```

[code/04-type-conversions/bitcast_float_bits.mojo](code/04-type-conversions/bitcast_float_bits.mojo)

The lane count can change as long as the total width stays the same. One
`UInt32` becomes four `UInt8` lanes in memory order, which depends on the
target's byte order. `Endian.native()` reports it.

```mojo
from std.memory import bitcast
from std.sys import Endian
from std.testing import assert_equal


def main() raises:
    var word = UInt32(0x0A0B0C0D)
    var lanes = bitcast[DType.uint8, 4](word)
    if Endian.native() == .little:
        assert_equal(lanes, SIMD[DType.uint8, 4](0x0D, 0x0C, 0x0B, 0x0A))
    else:
        assert_equal(lanes, SIMD[DType.uint8, 4](0x0A, 0x0B, 0x0C, 0x0D))
```

[code/04-type-conversions/bitcast_lanes_endian.mojo](code/04-type-conversions/bitcast_lanes_endian.mojo)

The width check happens at compile time.

```mojo
from std.memory import bitcast
from std.sys import argv


def main():
    var word = UInt32(len(argv()))
    print(bitcast[DType.uint64](word))
```

[code/04-type-conversions/bitcast_width_mismatch_fails.mojo](code/04-type-conversions/bitcast_width_mismatch_fails.mojo)

### `unsafe_bitcast` for pointers

`Pointer.unsafe_bitcast[U]()` changes the pointee type and keeps the address
and the origin. Reading a `UInt32` through a `UInt8` pointer exposes its
bytes in memory order, and writes through the new pointer change the
original value. Nothing checks that `U` fits the size, alignment, or bit
patterns of what's actually there; that part is yours.

```mojo
from std.sys import Endian
from std.testing import assert_equal


def main() raises:
    var header = UInt32(0x11223344)
    var bytes = Pointer(to=header).unsafe_bitcast[UInt8]()
    var first = bytes[unsafe_offset=0]
    bytes[unsafe_offset=0] = 0xFF  # the write lands in header's first byte
    if Endian.native() == .little:
        assert_equal(first, 0x44)
        assert_equal(header, 0x112233FF)
    else:
        assert_equal(first, 0x11)
        assert_equal(header, 0xFF223344)
```

[code/04-type-conversions/pointer_bitcast_bytes.mojo](code/04-type-conversions/pointer_bitcast_bytes.mojo)

### `rebind` and `downcast`

`rebind` isn't a reinterpretation of bits. It asserts that two type
expressions name the same type once parameters resolve. Inside
`comptime if width == 4`, `SIMD[DType.int32, width]` and `SIMD[DType.int32, 4]`
are the same type, but the type checker reasons about the expressions before
instantiation and needs `rebind` to accept the return.

```mojo
from std.testing import assert_equal


def as_quad[width: SIMDLength](lanes: SIMD[DType.int32, width]) -> SIMD[DType.int32, 4]:
    comptime if width == 4:
        return rebind[SIMD[DType.int32, 4]](lanes)
    else:
        return SIMD[DType.int32, 4](0)


def main() raises:
    var quad = SIMD[DType.int32, 4](10, 20, 30, 40)
    assert_equal(as_quad(quad), quad)
    assert_equal(as_quad(SIMD[DType.int32, 2](10, 20)), SIMD[DType.int32, 4](0))
```

[code/04-type-conversions/rebind_after_comptime_check.mojo](code/04-type-conversions/rebind_after_comptime_check.mojo)

If the types still differ after instantiation, compilation fails. `rebind`
can't turn four lanes into two.

```mojo
def main():
    var lanes = SIMD[DType.int32, 4](10, 20, 30, 40)
    var pair = rebind[SIMD[DType.int32, 2]](lanes)
    print(pair)
```

[code/04-type-conversions/rebind_mismatch_fails.mojo](code/04-type-conversions/rebind_mismatch_fails.mojo)

`downcast[T, Trait]` names a type `T` viewed as conforming to `Trait`.
Combined with a `comptime if conforms_to(T, Trait)` guard and `rebind`, it
lets generic code that accepts `T: AnyType` call trait methods on the types
that have them.

```mojo
from std.builtin.rebind import downcast
from std.testing import assert_equal


def describe[T: AnyType](ref value: T) -> String:
    comptime if conforms_to(T, Writable):
        return String(rebind[downcast[T, Writable]](value))
    else:
        return "<opaque>"


struct RawFrame:
    var length: Int

    def __init__(out self):
        self.length = 1500


def main() raises:
    assert_equal(describe(5500), "5500")
    assert_equal(describe(RawFrame()), "<opaque>")
```

[code/04-type-conversions/downcast_trait.mojo](code/04-type-conversions/downcast_trait.mojo)

### `UnsafeUnion`

`UnsafeUnion[*Ts]` from `std.ffi` stores one of several types in shared
storage with no tag, which makes it the layout match for a C union. Its size
is the size of its largest member. `unsafe_get[T]()` reads the storage as `T`
and can't check which member you stored last; reading the wrong one is
undefined behavior.

```mojo
from std.ffi import UnsafeUnion
from std.sys import size_of
from std.testing import assert_equal


def main() raises:
    var register = UnsafeUnion[Int32, Float64](Float64(2.5))
    assert_equal(size_of[type_of(register)](), 8)
    assert_equal(register.unsafe_get[Float64](), 2.5)
    register.unsafe_set(Int32(-7))
    assert_equal(register.unsafe_get[Int32](), -7)
```

[code/04-type-conversions/unsafe_union.mojo](code/04-type-conversions/unsafe_union.mojo)

Because the union never knows which member it holds, it can't run the right
destructor or copy constructor. It accepts only members whose copy, move,
and destruction are trivial.

```mojo
from std.ffi import UnsafeUnion


def main():
    var slot = UnsafeUnion[Int64, String](Int64(1))
    print(slot.unsafe_get[Int64]())
```

[code/04-type-conversions/unsafe_union_nontrivial_fails.mojo](code/04-type-conversions/unsafe_union_nontrivial_fails.mojo)
