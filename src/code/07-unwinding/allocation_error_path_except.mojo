# Claims:
# - An `except` that releases the resource and re-raises with `raise e^`
#   also satisfies the error edge.
# - The two paths can end the Allocation differently; each path needs
#   exactly one named destructor.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal, assert_raises


def checksum(length: Int) raises -> Int:
    if length == 0:
        raise Error("empty frame")
    return length * 31


def process_frame(length: Int) raises -> Int:
    var frame = alloc(Layout[UInt8](length=max(length, 1)))
    var sum: Int
    try:
        sum = checksum(length)
    except e:
        dealloc(frame^)
        raise e^
    dealloc(frame^)
    return sum


def main() raises:
    assert_equal(process_frame(2), 62)
    with assert_raises(contains="empty frame"):
        _ = process_frame(0)
