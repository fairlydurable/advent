# Claims:
# - `Allocation.unsafe_leak()` is a named destructor: it ends the handle and
#   returns the raw owning pointer, which the compiler no longer tracks.
# - The storage stays valid after the leak.
# - `Allocation(unsafe_owned_ptr=..., layout=...)` takes ownership back, as
#   long as the layout matches the original `alloc` call.
from std.memory import alloc, dealloc, Allocation, Layout
from std.testing import assert_equal


def main() raises:
    comptime layout = Layout[Int64](length=3)
    var handle = alloc(layout)
    var raw = handle^.unsafe_leak()

    for index in range(3):
        raw.unsafe_offset(index).write(Int64(index * 1024))
    var last = raw[unsafe_offset=2]

    var reclaimed = Allocation(unsafe_owned_ptr=raw, layout=layout)
    dealloc(reclaimed^)
    assert_equal(last, 2048)
