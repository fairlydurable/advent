# 2. Data layout

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/memory/alloc.mojo, Mojo/stdlib/std/memory/maybe_uninit.mojo, Mojo/stdlib/std/utils/_nicheable.mojo, Mojo/stdlib/std/ffi/unsafe_union.mojo, Mojo/stdlib/std/collections/array.mojo, Mojo/stdlib/std/collections/list.mojo, Mojo/stdlib/std/sys/_libc.mojo, Mojo/docs/site/reference/decorators/align.mdx, Mojo/docs/site/manual/interop/data-types.mdx -->

How Mojo lays out structs, tuples, zero-sized types, views, opaque foreign types, niches, unions, SIMD values, and aligned types.

## Overview

Low-level code needs to know where bytes sit. Every claim in this chapter
comes with a sample that measures it with `size_of`, `align_of`, and
address arithmetic on `Pointer(to=)`, so you can rerun the measurement when
the compiler changes. Import both functions from `std.sys`.

## 2.1 Default struct layout

*Rustonomicon counterpart: repr(Rust).*

### Declaration order, natural alignment

Mojo lays out struct fields in the order you declare them. Each field starts
at the next multiple of its own alignment, the struct's alignment is the
largest alignment among its fields, and the struct's size rounds up to a
multiple of that alignment. The compiler doesn't reorder fields:

```mojo
# Claim: struct fields sit in memory in declaration order; the compiler
# doesn't reorder them to remove padding.
# Claim: each field starts at a multiple of its alignment, and the struct's
# size rounds up to a multiple of its own alignment.
from std.sys import size_of, align_of
from std.testing import assert_equal


struct SensorFrame:
    var status: UInt8
    var timestamp_ns: Int64
    var channel: UInt16

    def __init__(out self):
        self.status = 1
        self.timestamp_ns = 1_700_000_000_000
        self.channel = 7


def main() raises:
    var frame = SensorFrame()
    var base = Int(Pointer(to=frame))
    assert_equal(Int(Pointer(to=frame.status)) - base, 0)
    assert_equal(Int(Pointer(to=frame.timestamp_ns)) - base, 8)
    assert_equal(Int(Pointer(to=frame.channel)) - base, 16)
    assert_equal(size_of[SensorFrame](), 24)
    assert_equal(align_of[SensorFrame](), 8)
```

[code/02-data-layout/field_order_is_declaration_order.mojo](code/02-data-layout/field_order_is_declaration_order.mojo)

That makes the layout predictable, and it makes padding your responsibility.
Ordering fields from largest alignment to smallest removes the interior
padding. Across a thousand elements, the difference is 8 KB:

```mojo
# Claim: ordering fields from largest alignment to smallest removes the
# interior padding; the compiler leaves that choice to the author.
from std.sys import size_of
from std.testing import assert_equal


struct LooseFrame:
    var status: UInt8
    var timestamp_ns: Int64
    var channel: UInt16

    def __init__(out self):
        self.status = 0
        self.timestamp_ns = 0
        self.channel = 0


struct TightFrame:
    var timestamp_ns: Int64
    var channel: UInt16
    var status: UInt8

    def __init__(out self):
        self.timestamp_ns = 0
        self.channel = 0
        self.status = 0


def main() raises:
    assert_equal(size_of[LooseFrame](), 24)
    assert_equal(size_of[TightFrame](), 16)
    # 11 bytes of data either way; the rest is padding.
    assert_equal(size_of[Array[TightFrame, 1000]](), 16_000)
```

[code/02-data-layout/reorder_fields_by_hand.mojo](code/02-data-layout/reorder_fields_by_hand.mojo)

`Tuple` follows the same rules as a struct:

```mojo
# Claim: `Tuple` follows the same rule as a struct: elements in order, each
# aligned, total rounded up to the largest alignment.
from std.sys import size_of, align_of
from std.testing import assert_equal


def main() raises:
    assert_equal(size_of[Tuple[Int8, Int64, Int8]](), 24)
    assert_equal(size_of[Tuple[Int64, Int8, Int8]](), 16)
    assert_equal(align_of[Tuple[Int8, Int64, Int8]](), 8)
```

[code/02-data-layout/tuple_layout.mojo](code/02-data-layout/tuple_layout.mojo)

Because order is stable, a struct whose fields are all C-compatible scalars,
pointers, nested structs, and `Array` values matches the C declaration with
the same field order. Chapter 11 covers the foreign-function side.

### Raising alignment with `@align`

`@align(N)` sets a minimum alignment for a struct. The size rounds up to a
multiple of N, so each element of an array sits on its own N-byte boundary,
the usual way to keep per-thread counters on separate cache lines. `@align`
can't lower alignment below what the fields need, and a struct that contains
an aligned field inherits its alignment. Heap allocations honor it too:

```mojo
# Claim: `@align(N)` raises a struct's alignment to at least N bytes, and its
# size rounds up to a multiple of that alignment, so arrays of it put each
# element on its own N-byte boundary.
# Claim: `@align` can't lower alignment below what the fields need.
# Claim: an aligned field passes its alignment to the containing struct.
from std.memory import alloc, dealloc, Layout
from std.sys import size_of, align_of
from std.testing import assert_equal


@align(64)
@fieldwise_init
struct HitCounter:
    var hits: Int


@align(4)
@fieldwise_init
struct WideField:
    var total: Int64


struct Shard:
    var counter: HitCounter
    var shard_id: Int

    def __init__(out self, shard_id: Int):
        self.counter = HitCounter(0)
        self.shard_id = shard_id


def main() raises:
    assert_equal(align_of[HitCounter](), 64)
    assert_equal(size_of[HitCounter](), 64)
    assert_equal(size_of[Array[HitCounter, 4]](), 256)
    assert_equal(align_of[WideField](), 8)
    assert_equal(align_of[Shard](), 64)
    assert_equal(size_of[Shard](), 128)

    var counters = alloc(Layout[HitCounter](length=4))
    var address = Int(counters.unsafe_ptr())
    dealloc(counters^)
    assert_equal(address % 64, 0)  # The heap honors the type's alignment.
```

[code/02-data-layout/align_decorator.mojo](code/02-data-layout/align_decorator.mojo)

### SIMD aligns to its width

`SIMD[DType.float32, 4]` and `Array[Float32, 4]` both hold 16 bytes. The SIMD
type aligns to its full width, so it can load in one aligned instruction;
`Array` aligns like its element. Put a one-byte field in front, and the
struct sizes come out as 32 and 20:

```mojo
# Claim: `SIMD[DType.float32, 4]` and `Array[Float32, 4]` both hold 16 bytes,
# but SIMD aligns to its full width while Array aligns like its element.
# Claim: that difference changes the size of a struct that contains them.
from std.sys import size_of, align_of
from std.testing import assert_equal


struct VectorSample:
    var quality: UInt8
    var components: SIMD[DType.float32, 4]

    def __init__(out self):
        self.quality = 0
        self.components = SIMD[DType.float32, 4](0)


struct ArraySample:
    var quality: UInt8
    var components: Array[Float32, 4]

    def __init__(out self):
        self.quality = 0
        self.components = Array[Float32, 4](fill=0)


def main() raises:
    assert_equal(size_of[SIMD[DType.float32, 4]](), 16)
    assert_equal(align_of[SIMD[DType.float32, 4]](), 16)
    assert_equal(size_of[Array[Float32, 4]](), 16)
    assert_equal(align_of[Array[Float32, 4]](), 4)
    assert_equal(size_of[VectorSample](), 32)
    assert_equal(size_of[ArraySample](), 20)
    assert_equal(align_of[SIMD[DType.float64, 8]](), 64)
```

[code/02-data-layout/simd_versus_array_alignment.mojo](code/02-data-layout/simd_versus_array_alignment.mojo)

Wide vectors take wide alignment: `SIMD[DType.float64, 8]` aligns to 64
bytes. Use `Array` for a field that has to match a C array, and `SIMD` for a
field you compute on.

### No packed layouts

Mojo has no packed structs and no bitfields. A wire format with fields at
unaligned offsets stays as bytes, and the code loads each field from its
offset, passing `alignment=1` so the load doesn't assume an aligned address:

```mojo
# Claim: Mojo has no packed struct layout. To read a packed wire record,
# keep the bytes and load each field from its byte offset, telling the load
# that the address may be unaligned (`alignment=1`).
# Claim: the same record declared as a struct takes 12 bytes, not 7.
from std.sys import size_of
from std.testing import assert_equal


struct WireHeader:
    var kind: UInt8
    var sequence: UInt32
    var length: UInt16

    def __init__(out self):
        self.kind = 0
        self.sequence = 0
        self.length = 0


def main() raises:
    assert_equal(size_of[WireHeader](), 12)

    # kind=2, sequence=0x01020304, length=0x0506, no padding. The loads
    # assume a little-endian target.
    var packet: Array[UInt8, 7] = [0x02, 0x04, 0x03, 0x02, 0x01, 0x06, 0x05]
    var bytes = packet.unsafe_ptr()

    var kind = bytes[]
    var sequence = bytes.unsafe_offset(1).unsafe_bitcast[UInt32]().unsafe_load[
        alignment=1
    ]()
    var length = bytes.unsafe_offset(5).unsafe_bitcast[UInt16]().unsafe_load[
        alignment=1
    ]()

    assert_equal(kind, 2)
    assert_equal(sequence, 0x01020304)
    assert_equal(length, 0x0506)
```

[code/02-data-layout/packed_record_by_hand.mojo](code/02-data-layout/packed_record_by_hand.mojo)

## 2.2 Exotically sized types

*Rustonomicon counterpart: Exotically Sized Types.*

### Dynamically sized types

Mojo has no dynamically sized types. Every type has a size known at compile
time, and data whose length is known only at run time lives behind a value
that carries the length. A `Span` or `StringSpan` stores a pointer and a
length, 16 bytes in all. A `List` stores its allocation (pointer and
capacity) and its length, 24 bytes. An `Array[T, N]` moves the length into
the type, so it needs no length field at all. One function can accept views
of both:

```mojo
# Claim: Mojo has no dynamically sized types. Runtime-length data lives
# behind a view that stores a pointer and a length side by side (`Span`,
# `StringSpan`), or puts the length in the type (`Array[T, N]`).
# Claim: a `List` stores its pointer, capacity, and length inline.
from std.sys import size_of
from std.testing import assert_equal


def total(readings: Span[Int, _]) -> Int:
    var sum = 0
    for reading in readings:
        sum += reading
    return sum


def main() raises:
    assert_equal(size_of[Span[Int, MutUntrackedOrigin]](), 16)
    assert_equal(size_of[StringSpan[ImmStaticOrigin]](), 16)
    assert_equal(size_of[List[Int]](), 24)
    assert_equal(size_of[Array[Int, 3]](), 24)

    var hourly: List[Int] = [12, 15, 19, 22]
    var fixed = Array[Int, 3](fill=7)
    assert_equal(total(Span(hourly)), 68)
    assert_equal(total(Span(fixed)), 21)
```

[code/02-data-layout/views_carry_their_length.mojo](code/02-data-layout/views_carry_their_length.mojo)

### Zero-sized types

A struct with no fields has size 0 and alignment 1. Zero-sized fields take no
space: adjacent ones share an address with the next field, and a trailing
one sits one past the end of its struct. An `Array` of a thousand of them is
still zero bytes:

```mojo
# Claim: a struct with no fields occupies zero bytes, with alignment 1.
# Claim: an Array of a thousand of them also occupies zero bytes.
# Claim: zero-sized fields take no space; adjacent ones share an address,
# and a trailing one sits at the end of the struct.
from std.sys import size_of, align_of
from std.testing import assert_equal, assert_true


struct Unit:
    def __init__(out self):
        pass


@fieldwise_init
struct Measurement:
    var unit_before: Unit
    var millivolts: Int32
    var unit_after: Unit


def main() raises:
    assert_equal(size_of[Unit](), 0)
    assert_equal(align_of[Unit](), 1)
    assert_equal(size_of[Array[Unit, 1000]](), 0)
    assert_equal(size_of[Measurement](), 4)

    var reading = Measurement(Unit(), 3300, Unit())
    var base = Int(Pointer(to=reading))
    assert_equal(Int(Pointer(to=reading.unit_before)) - base, 0)
    assert_equal(Int(Pointer(to=reading.millivolts)) - base, 0)
    assert_equal(Int(Pointer(to=reading.unit_after)) - base, 4)
```

[code/02-data-layout/zero_sized_types.mojo](code/02-data-layout/zero_sized_types.mojo)

Zero-sized types matter most to code that manages memory by hand. `alloc` of
a zero-sized type never calls the system allocator. It returns a
well-aligned dangling pointer, and `dealloc` frees nothing. Every offset from
that pointer is the same address, which is correct, since every element is
zero bytes wide:

```mojo
# Claim: `alloc` of a zero-sized type never calls the allocator; it hands
# back a well-aligned dangling pointer, and `dealloc` of it frees nothing.
# Claim: pointer arithmetic on a zero-sized type doesn't move the pointer,
# so every element shares one address.
# Claim: a List of zero-sized values still counts its elements.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


@fieldwise_init
struct Tick(Copyable):
    pass


def main() raises:
    var ticks = alloc(Layout[Tick](length=1_000_000))
    var first = ticks.unsafe_ptr()
    var last = first.unsafe_offset(999_999)
    var same_address = Int(first) == Int(last)
    var length = len(ticks)
    dealloc(ticks^)
    assert_equal(same_address, True)
    assert_equal(length, 1_000_000)

    var log = List[Tick]()
    for _ in range(500):
        log.append(Tick())
    assert_equal(len(log), 500)
```

[code/02-data-layout/zero_sized_allocation.mojo](code/02-data-layout/zero_sized_allocation.mojo)

Code that computes distances between elements breaks on zero-sized types,
because every element shares one address. `offset_from` refuses them at
compile time:

```mojo
# EXPECT-ERROR: distance between pointers is undefined for a zero-sized type, so the call fails to instantiate
# EXPECT-MATCH: requires a non-zero-sized pointee type
# Claim: `offset_from` rejects zero-sized pointee types at compile time,
# since every element shares one address.
from std.memory import alloc, dealloc, Layout


@fieldwise_init
struct Tick(Copyable):
    pass


def main():
    var ticks = alloc(Layout[Tick](length=8))
    var first = ticks.unsafe_ptr()
    print(first.unsafe_offset(5).offset_from(first))
    dealloc(ticks^)
```

[code/02-data-layout/zero_sized_offset_from_fails.mojo](code/02-data-layout/zero_sized_offset_from_fails.mojo)

A container you write needs the same care. Chapter 9 handles zero-sized
elements in a hand-built `List`.

### Empty types

A type with no values tells the compiler that a path can't continue. Mojo's
built-in one is `Never`, the return type of a function that never returns.
A call to such a function ends its path, so a function with a non-`None`
return type can end a branch with it instead of a `return`:

```mojo
# Claim: `Never` is the return type of a function that can't return. A call
# to it ends a path, so a function that must return a value can end a path
# with that call instead of a `return`.
from std.os import abort
from std.testing import assert_equal


def fail_closed(reason: StaticString) -> Never:
    abort(reason)


def checked_rpm(raw: Int) -> Int:
    if raw >= 0 and raw <= 12_000:
        return raw
    fail_closed("rpm sensor out of range")


def main() raises:
    assert_equal(checked_rpm(3600), 3600)
```

[code/02-data-layout/never_returns.mojo](code/02-data-layout/never_returns.mojo)

A struct that declares no constructor gets close to an empty type from the
outside. Mojo synthesizes only a move constructor for it, which needs an
existing value, so code can name the type but can't create the first value:

```mojo
# EXPECT-ERROR: a struct that declares no constructor has no way to make a value from scratch
# EXPECT-MATCH: invalid initialization
# Claim: a struct with no `__init__` exists only as a type. Mojo
# synthesizes a move constructor for it, which needs an existing value, so
# nothing can create the first one.
struct SessionToken:
    pass


def main():
    var token = SessionToken()
```

[code/02-data-layout/no_constructor_fails.mojo](code/02-data-layout/no_constructor_fails.mojo)

### Opaque foreign types

Mojo has no dedicated extern type. A fieldless struct that Mojo code never
constructs fills the role: values exist only behind a `Pointer` that foreign
code hands out, and the pointee type keeps handles of different foreign
types from mixing. `Optional[Pointer[...]]` costs nothing extra (section 2.3
explains why), so it models a nullable C return directly:

```mojo
# Claim: an opaque foreign type maps to a fieldless struct that Mojo code
# never constructs; values only ever exist behind a `Pointer` that foreign
# code hands out.
# Claim: `Optional[Pointer[...]]` has the size of a bare pointer, so it
# models a nullable C return with no extra tag.
# Claim: one foreign symbol has one signature across the whole program.
# The standard library already declares `fclose` with an
# `Optional[Pointer[NoneType, ...]]` argument, so this code converts its
# handle to that exact type before the call.
from std.ffi import external_call
from std.sys import size_of
from std.testing import assert_equal


struct CFile:
    pass


comptime FileHandle = Pointer[CFile, MutUntrackedOrigin]
comptime StdioFile = Optional[Pointer[NoneType, MutUntrackedOrigin]]


def main() raises:
    assert_equal(size_of[CFile](), 0)
    assert_equal(size_of[Optional[FileHandle]](), size_of[FileHandle]())

    var maybe_file = external_call["tmpfile", Optional[FileHandle]]()
    if not maybe_file:
        raise Error("tmpfile() returned NULL")
    var handle = maybe_file.value()

    _ = external_call["fputc", Int32](Int32(ord("M")), handle)
    external_call["rewind", NoneType](handle)
    var first_byte = external_call["fgetc", Int32](handle)

    var as_stdio: StdioFile = handle.unsafe_bitcast[NoneType]()
    var closed = external_call["fclose", Int32](as_stdio)

    assert_equal(first_byte, Int32(ord("M")))
    assert_equal(closed, 0)
```

[code/02-data-layout/opaque_foreign_handle.mojo](code/02-data-layout/opaque_foreign_handle.mojo)

The sample also shows a rule that bites in practice: a foreign symbol has
one signature across the whole program, including the standard library's
own declarations. The standard library already declares `fclose` with an
`Optional[Pointer[NoneType, ...]]` argument, so declaring it again with a
different argument type fails to compile even though both types have the
same bits. Convert to the existing type before the call.

`OpaquePointer` (a `Pointer[NoneType, ...]`) is the C `void*`. Use it where
the foreign API really is untyped, and a typed handle everywhere else.

## 2.3 Other layouts

*Rustonomicon counterpart: Alternative representations (repr(C),
repr(transparent), repr(u*), repr(packed), repr(align)).*

Mojo has no layout attributes besides `@align`. The other representation
choices come from the types you pick: niches, tagged and untagged unions,
register passing, and `MaybeUninit`.

### Niches

A `Pointer` is never null, so the null address is an unused bit pattern: a
niche. `Optional` stores `None` in that niche, which makes
`Optional[Pointer[...]]` exactly the size of the pointer. Standard library
owners that hold a pointer inherit the niche, including `ArcPointer`,
`OwnedPointer`, `String`, and `List`:

```mojo
# Claim: a non-nullable `Pointer` leaves the null address unused, and
# `Optional` stores `None` in that niche, so `Optional[Pointer[...]]` is the
# same size as the pointer.
# Claim: standard library owners built on pointers inherit the niche:
# `ArcPointer`, `OwnedPointer`, `String`, and `List`.
from std.memory import ArcPointer, OwnedPointer
from std.sys import size_of
from std.testing import assert_equal


def main() raises:
    comptime Raw = Pointer[Int, MutUntrackedOrigin]
    assert_equal(size_of[Optional[Raw]](), size_of[Raw]())
    assert_equal(size_of[Optional[ArcPointer[Int]]](), 8)
    assert_equal(size_of[Optional[OwnedPointer[Int]]](), 8)
    assert_equal(size_of[Optional[String]](), size_of[String]())
    assert_equal(size_of[Optional[List[Int]]](), size_of[List[Int]]())

    var cached: Optional[ArcPointer[String]] = None
    assert_equal(Bool(cached), False)
    cached = ArcPointer(String("eu-central"))
    assert_equal(cached.value()[], "eu-central")
```

[code/02-data-layout/niche_optional_pointer.mojo](code/02-data-layout/niche_optional_pointer.mojo)

Types that use every bit pattern have no niche, and `Optional` adds a tag
plus whatever padding the alignment demands. `Optional[Bool]` is 2 bytes,
because `Bool` gets no niche from its seven unused bits. One niche serves one
`Optional`, so nesting pays for a tag. And a struct you write doesn't get a
niche from its fields, even when one of them is a `String`; the niche
machinery lives in a private standard library module. Measure before you
assume:

```mojo
# Claim: a type that uses every bit pattern has no niche, so `Optional` adds
# a tag and the padding its alignment requires: `Int`, `Float64`, and even
# `Bool` grow.
# Claim: one niche serves one `Optional`; a nested `Optional` pays a tag.
# Claim: a user struct doesn't get a niche from its fields, even when a
# field is a `String`.
from std.sys import size_of
from std.testing import assert_equal


@fieldwise_init
struct Route(Movable):
    var destination: String
    var hops: Int


def main() raises:
    assert_equal(size_of[Optional[Int]](), 16)
    assert_equal(size_of[Optional[Float64]](), 16)
    assert_equal(size_of[Optional[Bool]](), 2)

    comptime Raw = Pointer[Int, MutUntrackedOrigin]
    assert_equal(size_of[Optional[Optional[Raw]]](), 16)
    assert_equal(size_of[Optional[Optional[String]]](), 32)

    assert_equal(size_of[Route](), 32)
    assert_equal(size_of[Optional[Route]](), 40)
```

[code/02-data-layout/types_without_a_niche.mojo](code/02-data-layout/types_without_a_niche.mojo)

### Tagged and untagged unions

`Variant` is a tagged union: its largest arm plus a tag, rounded to its
alignment. `UnsafeUnion` from `std.ffi` is untagged, exactly the size of its
largest member, and it keeps no record of which member holds the live value.
Reading back the member you wrote is defined. Reading any other member is
undefined behavior; use `bitcast` to reinterpret bits instead:

```mojo
# Claim: `Variant` is a tagged union: the size of its largest arm plus a
# tag, rounded to its alignment.
# Claim: `UnsafeUnion` is untagged: exactly the size of its largest member,
# with no record of which member is live. Reading the member you wrote is
# defined; reading any other member is undefined behavior.
from std.ffi import UnsafeUnion
from std.sys import size_of
from std.testing import assert_equal
from std.utils import Variant


def main() raises:
    assert_equal(size_of[Variant[Int64, String]](), 32)
    assert_equal(size_of[Variant[UInt8, UInt16]](), 4)
    assert_equal(size_of[UnsafeUnion[Int64, Float32]](), 8)

    var setting = UnsafeUnion[Int64, Float32](Float32(0.25))
    assert_equal(setting.unsafe_get[Float32](), 0.25)
    setting.unsafe_set(Int64(86_400))
    assert_equal(setting.unsafe_get[Int64](), 86_400)
```

[code/02-data-layout/tagged_and_untagged_unions.mojo](code/02-data-layout/tagged_and_untagged_unions.mojo)

`UnsafeUnion` requires every member to have trivial copy, move, and
destruction, matching C unions, which have no constructors or destructors.

### Register-passable types

A struct that conforms to `TrivialRegisterPassable` travels in registers and
copies with a bitwise copy. Binding it to a `var` still gives it an address,
so `Pointer(to=)` works:

```mojo
# Claim: a `TrivialRegisterPassable` struct travels in registers, copies
# implicitly with a bitwise copy, and still has an address when bound to a
# `var`, so `Pointer(to=)` works on it.
# Claim: a `RegisterPassable` (non-trivial) struct may define `__deinit__`,
# and Mojo runs it after the value's last use.
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Rgba(TrivialRegisterPassable):
    var packed: UInt32


@fieldwise_init
struct Share(RegisterPassable):
    var owner: ArcPointer[String]


def main() raises:
    var fill = Rgba(0xFF336699)
    var stroke = fill  # Implicit copy.
    stroke.packed = 0xFF000000
    assert_equal(fill.packed, 0xFF336699)
    var fill_ref = Pointer(to=fill)
    assert_equal(fill_ref[].packed, 0xFF336699)

    var tenant = ArcPointer(String("acme-prod"))
    var lease = Share(tenant.copy())
    assert_equal(tenant.count(), 2)
    _ = lease^
    assert_equal(tenant.count(), 1)
```

[code/02-data-layout/register_passable.mojo](code/02-data-layout/register_passable.mojo)

`RegisterPassable` without `Trivial` allows a destructor. A trivial type
promises that destroying it has no observable effect, so the compiler
rejects a `__deinit__` on one:

```mojo
# EXPECT-ERROR: a trivial register-passable type can't declare a destructor
# EXPECT-MATCH: trivial types must not declare
# Claim: `TrivialRegisterPassable` promises no observable destruction, so
# the compiler rejects a `__deinit__` on it.
@fieldwise_init
struct Rgba(TrivialRegisterPassable):
    var packed: UInt32

    def __deinit__(deinit self):
        print("released color")


def main():
    var fill = Rgba(0xFF336699)
```

[code/02-data-layout/trivial_type_deinit_fails.mojo](code/02-data-layout/trivial_type_deinit_fails.mojo)

### `MaybeUninit` keeps the layout of `T`

`MaybeUninit[T]` has exactly the size and alignment of `T`, so it can occupy
`T`'s slot in raw memory or serve as a C-style out argument before a value
exists. Chapter 5 covers the rules for reading one:

```mojo
# Claim: `MaybeUninit[T]` has exactly the size and alignment of `T`, so it
# can stand in for `T` in raw memory, including as a C-style out argument.
from std.memory import MaybeUninit
from std.sys import size_of, align_of
from std.testing import assert_equal


def main() raises:
    assert_equal(size_of[MaybeUninit[String]](), size_of[String]())
    assert_equal(size_of[MaybeUninit[Int8]](), 1)
    assert_equal(
        align_of[MaybeUninit[SIMD[DType.float32, 4]]](),
        align_of[SIMD[DType.float32, 4]](),
    )

    var slot = MaybeUninit[Int]()
    slot.write(4096)
    assert_equal(slot.unsafe_assume_init(), 4096)
```

[code/02-data-layout/maybe_uninit_layout.mojo](code/02-data-layout/maybe_uninit_layout.mojo)
