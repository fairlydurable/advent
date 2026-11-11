# Claim: unsafe_bitcast on a Pointer changes the pointee type and keeps the
# address and origin. Reading a UInt32 through a UInt8 pointer exposes its
# bytes in memory order, and writes through it change the original value.
from std.sys import Endian
from std.testing import assert_equal


def main() raises:
    var header = UInt32(0x11223344)
    var bytes = Pointer(to=header).unsafe_bitcast[UInt8]()
    var first = bytes[unsafe_offset=0]
    bytes[unsafe_offset=0] = 0xFF  # the write lands in header's first byte
    if Endian.native() == .little:
        assert_equal(first, 0x44)
        assert_equal(header, 0x112233FF)
    else:
        assert_equal(first, 0x11)
        assert_equal(header, 0xFF223344)
