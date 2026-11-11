# Claims:
# - Mojo memory lent to C stays owned by its Allocation: C writes through the
#   pointer, and dealloc() releases it afterward.
# - unsafe_leak() turns an Allocation into a bare pointer that can travel
#   through C as an opaque handle; ThinAllocation plus the original Layout
#   turns it back into something dealloc() accepts.

from std.ffi import c_int, c_size_t, external_call
from std.memory import Layout, ThinAllocation, alloc, dealloc
from std.testing import assert_equal


def main() raises:
    var layout = Layout[UInt8](length=32)
    var frame = alloc(layout)
    # void *memset(void *dest, int byte, size_t count);
    _ = external_call["memset", MutOpaquePointer[MutUntrackedOrigin]](
        frame.unsafe_ptr(), c_int(0x7E), c_size_t(len(frame))
    )
    var last = frame.unsafe_ptr()[unsafe_offset=31]
    dealloc(frame^)
    assert_equal(last, 0x7E)

    # Hand ownership out as a raw handle, as a C API that stores a void*
    # would hold it, then reclaim it.
    var handle = alloc(layout).unsafe_leak()
    handle.write(0x01)
    var reclaimed = ThinAllocation(unsafe_owned_ptr=handle)
    dealloc(reclaimed^.unsafe_with_layout(layout))
