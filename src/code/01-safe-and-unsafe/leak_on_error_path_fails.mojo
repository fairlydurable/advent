# EXPECT-ERROR: a raising call between alloc and dealloc leaves an error path that abandons the Allocation
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim: the linear-type check covers error paths, not only the happy path.
from std.memory import alloc, dealloc, Layout


def parse_header(byte_count: Int) raises -> Int:
    if byte_count < 16:
        raise Error("truncated header")
    return byte_count - 16


def main() raises:
    var packet = alloc(Layout[UInt8](length=1500))
    var payload = parse_header(len(packet))
    print("payload bytes:", payload)
    dealloc(packet^)
