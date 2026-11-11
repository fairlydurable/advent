# Claim: `Tuple` follows the same rule as a struct: elements in order, each
# aligned, total rounded up to the largest alignment.
from std.sys import size_of, align_of
from std.testing import assert_equal


def main() raises:
    assert_equal(size_of[Tuple[Int8, Int64, Int8]](), 24)
    assert_equal(size_of[Tuple[Int64, Int8, Int8]](), 16)
    assert_equal(align_of[Tuple[Int8, Int64, Int8]](), 8)
