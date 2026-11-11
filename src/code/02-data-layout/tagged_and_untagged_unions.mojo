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
