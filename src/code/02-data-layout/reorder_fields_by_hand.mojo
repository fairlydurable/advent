# Claim: ordering fields from largest alignment to smallest removes the
# interior padding; the compiler leaves that choice to the author.
from std.sys import size_of
from std.testing import assert_equal


struct LooseFrame:
    var status: UInt8
    var timestamp_ns: Int64
    var channel: UInt16

    def __init__(out self):
        self.status = 0
        self.timestamp_ns = 0
        self.channel = 0


struct TightFrame:
    var timestamp_ns: Int64
    var channel: UInt16
    var status: UInt8

    def __init__(out self):
        self.timestamp_ns = 0
        self.channel = 0
        self.status = 0


def main() raises:
    assert_equal(size_of[LooseFrame](), 24)
    assert_equal(size_of[TightFrame](), 16)
    # 11 bytes of data either way; the rest is padding.
    assert_equal(size_of[Array[TightFrame, 1000]](), 16_000)
