# Claim: unsafe_uninit_move_n() relocates initialized values into
# uninitialized memory and leaves the source uninitialized, so the old
# allocation can be freed without destroying anything.
# Claim: unsafe_uninit_copy_n() duplicates values; unsafe_destroy_n() runs
# destructors over a range.
# Claim: two pointers into the same allocation share an origin, so passing
# them as dest and src trips exclusivity checking; casting one side to
# MutUntrackedOrigin opts that call out of the check.
from std.memory import (
    alloc,
    dealloc,
    Layout,
    unsafe_uninit_move_n,
    unsafe_uninit_copy_n,
    unsafe_destroy_n,
)
from std.testing import assert_equal


def main() raises:
    var old = alloc(Layout[String](length=3))
    var stages = old.unsafe_ptr()
    stages.unsafe_write("inlet")
    stages.unsafe_offset(1).unsafe_write("pump")
    stages.unsafe_offset(2).unsafe_write("outlet")

    var grown = alloc(Layout[String](length=6))
    unsafe_uninit_move_n[overlapping=False](
        dest=grown.unsafe_ptr(), src=old.unsafe_ptr(), count=3
    )
    dealloc(old^)  # nothing left to destroy in the old block

    var data = grown.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    unsafe_uninit_copy_n[overlapping=False](
        dest=data.unsafe_offset(3), src=data, count=3
    )
    var copied = data[unsafe_offset=4]
    unsafe_destroy_n(data, 6)
    dealloc(grown^)
    assert_equal(copied, "pump")
