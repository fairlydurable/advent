# Claim: bitcast can change the lane count when total width stays equal; one
# UInt32 becomes four UInt8 lanes in memory order.
# Claim: memory order depends on the target's byte order, which
# Endian.native() reports.
from std.memory import bitcast
from std.sys import Endian
from std.testing import assert_equal


def main() raises:
    var word = UInt32(0x0A0B0C0D)
    var lanes = bitcast[DType.uint8, 4](word)
    if Endian.native() == .little:
        assert_equal(lanes, SIMD[DType.uint8, 4](0x0D, 0x0C, 0x0B, 0x0A))
    else:
        assert_equal(lanes, SIMD[DType.uint8, 4](0x0A, 0x0B, 0x0C, 0x0D))
