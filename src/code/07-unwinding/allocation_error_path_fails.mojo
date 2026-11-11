# EXPECT-ERROR: a call that can raise would abandon a live Allocation on its error path
# EXPECT-MATCH: 'frame' abandoned without being explicitly destroyed
# Claim: linear types make error paths visible. The compiler checks the
# error edge of `checksum(...)` and rejects the leak there.
from std.memory import alloc, dealloc, Layout


def checksum(length: Int) raises -> Int:
    if length == 0:
        raise Error("empty frame")
    return length * 31


def process_frame(length: Int) raises -> Int:
    var frame = alloc(Layout[UInt8](length=length))
    var sum = checksum(length)
    dealloc(frame^)
    return sum


def main() raises:
    print(process_frame(64))
