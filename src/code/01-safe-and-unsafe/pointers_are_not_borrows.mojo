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
