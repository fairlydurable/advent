# Claim (3.2): trivial register-passable types (Int, Bool, SIMD) skip the
# exclusivity check because the callee receives copies. `step` keeps the value
# it had at the call, so the result is 3 + 3 + 3, not 3 + 3 + 6.
from std.testing import assert_equal


def bump_twice(mut count: Int, step: Int):
    count += step
    count += step


def main() raises:
    var count = 3
    bump_twice(count, count)
    assert_equal(count, 9)
