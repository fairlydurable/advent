# Claims:
# - `into_managed()` converts a linear Allocation into a ManagedAllocation,
#   which frees its storage in its destructor after its last use.
# - It frees storage without running element destructors.
from std.memory import alloc, Layout
from std.testing import assert_equal


def main() raises:
    var samples = alloc(Layout[Int32](length=8)).into_managed()
    var cursor = samples.unsafe_ptr()
    for index in range(len(samples)):
        cursor.unsafe_offset(index).write(Int32(index * index))
    assert_equal(cursor[unsafe_offset=7], 49)
    assert_equal(len(samples), 8)
