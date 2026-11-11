# Claims:
# - into_thin() drops the Layout and keeps only the owning pointer.
# - A ThinAllocation must be paired with its original Layout again before
#   dealloc() accepts it.
# - unsafe_leak() consumes the handle; the raw pointer it returns can be
#   re-wrapped as an owning handle.

from std.memory import Layout, ThinAllocation, alloc, dealloc
from std.testing import assert_equal


def main() raises:
    var layout = Layout[Int32](length=16)
    var thin = alloc(layout).into_thin()

    var ports = thin.unsafe_ptr()
    for index in range(16):
        ports.unsafe_offset(index).write(Int32(8000 + index))
    var last_port = ports[unsafe_offset=15]

    var raw = thin^.unsafe_leak()  # the compiler stops tracking the storage
    var owned_again = ThinAllocation(unsafe_owned_ptr=raw)
    dealloc(owned_again^.unsafe_with_layout(layout))

    # Assert after the release: assert_equal can raise, and a raise while the
    # handle is alive would abandon it on the error path.
    assert_equal(last_port, 8015)
