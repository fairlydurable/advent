# Claim: struct fields sit in memory in declaration order; the compiler
# doesn't reorder them to remove padding.
# Claim: each field starts at a multiple of its alignment, and the struct's
# size rounds up to a multiple of its own alignment.
from std.sys import size_of, align_of
from std.testing import assert_equal


struct SensorFrame:
    var status: UInt8
    var timestamp_ns: Int64
    var channel: UInt16

    def __init__(out self):
        self.status = 1
        self.timestamp_ns = 1_700_000_000_000
        self.channel = 7


def main() raises:
    var frame = SensorFrame()
    var base = Int(Pointer(to=frame))
    assert_equal(Int(Pointer(to=frame.status)) - base, 0)
    assert_equal(Int(Pointer(to=frame.timestamp_ns)) - base, 8)
    assert_equal(Int(Pointer(to=frame.channel)) - base, 16)
    assert_equal(size_of[SensorFrame](), 24)
    assert_equal(align_of[SensorFrame](), 8)
