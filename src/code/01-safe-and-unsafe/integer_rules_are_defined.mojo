# Claim: integer overflow wraps in two's complement, at every width.
# Claim: integer division and remainder by zero return 0 instead of trapping.
# Claim: `//` floors and `%` takes the sign of the divisor.
from std.testing import assert_equal


def main() raises:
    assert_equal(Int.MAX + 1, Int.MIN)
    var level: UInt8 = 250
    assert_equal(level + 10, 4)
    var signed_level: Int8 = 127
    assert_equal(signed_level + 1, -128)

    var shards = 0
    assert_equal(4096 // shards, 0)
    assert_equal(4096 % shards, 0)

    assert_equal(-7 // 2, -4)
    assert_equal(-7 % 2, 1)
