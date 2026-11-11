# Claim (3.2): the compiler checks exclusivity between the arguments of one call. A
# Pointer created earlier stays valid across a call that takes the same value
# `mut`, and both writes land, in program order.
from std.testing import assert_equal


def bump(mut count: Int):
    count += 1


def main() raises:
    var count = 3
    var cursor = Pointer(to=count)
    bump(count)
    cursor[] += 10
    assert_equal(count, 14)
