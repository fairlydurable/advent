# Claim: Mojo has no packed struct layout. To read a packed wire record,
# keep the bytes and load each field from its byte offset, telling the load
# that the address may be unaligned (`alignment=1`).
# Claim: the same record declared as a struct takes 12 bytes, not 7.
from std.sys import size_of
from std.testing import assert_equal


struct WireHeader:
    var kind: UInt8
    var sequence: UInt32
    var length: UInt16

    def __init__(out self):
        self.kind = 0
        self.sequence = 0
        self.length = 0


def main() raises:
    assert_equal(size_of[WireHeader](), 12)

    # kind=2, sequence=0x01020304, length=0x0506, no padding. The loads
    # assume a little-endian target.
    var packet: Array[UInt8, 7] = [0x02, 0x04, 0x03, 0x02, 0x01, 0x06, 0x05]
    var bytes = packet.unsafe_ptr()

    var kind = bytes[]
    var sequence = bytes.unsafe_offset(1).unsafe_bitcast[UInt32]().unsafe_load[
        alignment=1
    ]()
    var length = bytes.unsafe_offset(5).unsafe_bitcast[UInt16]().unsafe_load[
        alignment=1
    ]()

    assert_equal(kind, 2)
    assert_equal(sequence, 0x01020304)
    assert_equal(length, 0x0506)
