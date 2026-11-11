# Claim: an integer literal too large for its target type compiles without
# complaint and keeps only the low bits (two's complement wrap).
# Claim: the same holds in `comptime` declarations.
from std.testing import assert_equal


def main() raises:
    var level: UInt8 = 300  # 300 - 256
    assert_equal(level, 44)
    var offset: Int8 = 200  # 200 - 256
    assert_equal(offset, -56)
    comptime ceiling: UInt8 = 256
    assert_equal(ceiling, 0)
