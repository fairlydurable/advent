# Claims:
# - `finally` runs on both the normal and the error path, so a single
#   `dealloc` there satisfies the linear Allocation on every exit.
# - The error still propagates to the caller after `finally` runs.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal, assert_raises


def checksum(length: Int) raises -> Int:
    if length == 0:
        raise Error("empty frame")
    return length * 31


def process_frame(length: Int) raises -> Int:
    var frame = alloc(Layout[UInt8](length=max(length, 1)))
    try:
        return checksum(length)
    finally:
        dealloc(frame^)


def main() raises:
    assert_equal(process_frame(64), 1984)
    with assert_raises(contains="empty frame"):
        _ = process_frame(0)
