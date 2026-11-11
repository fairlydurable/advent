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
