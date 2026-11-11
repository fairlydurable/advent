# Claims:
# - A struct with no fields has size 0.
# - alloc() of a zero-sized type returns a dangling, well-aligned sentinel
#   without calling the allocator, and dealloc() of it is a no-op.
# - Offsetting a pointer to a zero-sized type does not move it.
# (mylist_final.mojo tests that MyList never allocates for these elements.)

from std.memory import Layout, alloc, dealloc
from std.sys import size_of
from std.testing import assert_equal, assert_true


struct Visited(Movable):
    """A zero-sized marker: its type carries all its information."""

    def __init__(out self):
        pass


def main() raises:
    assert_equal(size_of[Visited](), 0)

    var markers = alloc(Layout[Visited](length=1000))
    var base = markers.unsafe_ptr()
    var dangling = Pointer[Visited, MutUntrackedOrigin].unsafe_dangling()
    var base_address = Int(base)
    var last_address = Int(base.unsafe_offset(999))
    dealloc(markers^)

    assert_equal(base_address, Int(dangling))
    assert_equal(last_address, base_address)
