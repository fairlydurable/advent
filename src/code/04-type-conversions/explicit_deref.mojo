# Claim: `[]` dereferences Pointer, OwnedPointer, and ArcPointer to a reference
# of the pointee; methods and fields go through that reference.
# Claim: each level of indirection needs its own `[]`.
# Claim: copies of an ArcPointer share one pointee.
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
