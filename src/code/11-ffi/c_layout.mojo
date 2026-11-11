# Claims:
# - Mojo lays struct fields out in declaration order with C's padding rules,
#   so a struct that lists C's fields in C's order matches C's size.
# - SIMD[DType.float32, 4] aligns to 16 bytes, so it does not match C's
#   float[4]; Array[Float32, 4] aligns to 4 and does.
# - @align(16) raises a struct's alignment, like _Alignas(16).
# - UnsafeUnion is as large as its largest member.

from std.ffi import UnsafeUnion, c_char, c_double, c_int
from std.sys import align_of, size_of
from std.testing import assert_equal


@fieldwise_init
struct Reading(RegisterPassable):  # struct { char unit; double value; }
    var unit: c_char
    var value: c_double


@fieldwise_init
struct PackedFirst(RegisterPassable):  # struct { double value; char unit; }
    var value: c_double
    var unit: c_char


struct SimdVector:  # NOT struct { uint8_t tag; float v[4]; }
    var tag: UInt8
    var v: SIMD[DType.float32, 4]


struct ArrayVector:  # struct { uint8_t tag; float v[4]; }
    var tag: UInt8
    var v: Array[Float32, 4]


@align(16)
@fieldwise_init
struct CacheTag(RegisterPassable):  # struct { _Alignas(16) int id; }
    var id: c_int


def main() raises:
    assert_equal(size_of[Reading](), 16)  # 1 byte, 7 padding, 8 bytes
    assert_equal(size_of[PackedFirst](), 16)  # trailing padding to align 8
    assert_equal(size_of[SimdVector](), 32)
    assert_equal(size_of[ArrayVector](), 20)
    assert_equal(align_of[CacheTag](), 16)
    assert_equal(size_of[CacheTag](), 16)
    assert_equal(size_of[UnsafeUnion[c_int, c_double]](), 8)
