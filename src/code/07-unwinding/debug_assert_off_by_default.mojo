# Claims:
# - `debug_assert` checks compile out unless you build with `-D ASSERT=all`.
#   A default build skips this failing check and keeps running.
# - Treat `debug_assert` as documentation that a debug build can enforce,
#   never as a runtime guarantee.
from std.testing import assert_equal


def scale(reading: Int, divisor: Int) -> Int:
    debug_assert(divisor > 0, "divisor must be positive")
    return reading * 4


def main() raises:
    assert_equal(scale(25, 0), 100)
