# Claim: releasing the allocation on both the error path and the success
# path satisfies the linear-type check.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


def parse_header(byte_count: Int) raises -> Int:
    if byte_count < 16:
        raise Error("truncated header")
    return byte_count - 16


def payload_size(packet_bytes: Int) raises -> Int:
    var packet = alloc(Layout[UInt8](length=packet_bytes))
    var payload: Int
    try:
        payload = parse_header(len(packet))
    except e:
        dealloc(packet^)
        raise e^
    dealloc(packet^)
    return payload


def main() raises:
    assert_equal(payload_size(1500), 1484)
    var rejected = False
    try:
        _ = payload_size(8)
    except:
        rejected = True
    assert_equal(rejected, True)
