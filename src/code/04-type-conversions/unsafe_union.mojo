# Claim: UnsafeUnion stores one of several types in shared storage with no
# tag; its size is the size of its largest member.
# Claim: unsafe_get reads the storage as the requested type; it cannot check
# which member you last stored.
from std.ffi import UnsafeUnion
from std.sys import size_of
from std.testing import assert_equal


def main() raises:
    var register = UnsafeUnion[Int32, Float64](Float64(2.5))
    assert_equal(size_of[type_of(register)](), 8)
    assert_equal(register.unsafe_get[Float64](), 2.5)
    register.unsafe_set(Int32(-7))
    assert_equal(register.unsafe_get[Int32](), -7)
