# Claims:
# - A guard with no later uses dies right after construction, so its
#   destructor runs earlier than a scope-based reading suggests.
# - `deinit(guard^)` pins the end of the guard's life to that call.
from std.testing import assert_equal


struct DepthGuard[origin: MutOrigin](Movable):
    var depth: Pointer[Int, Self.origin]

    def __init__(out self, ref[Self.origin] depth: Int):
        depth += 1
        self.depth = Pointer(to=depth)

    def __deinit__(deinit self):
        self.depth[] -= 1


def main() raises:
    var unpinned_depth = 0
    _ = DepthGuard(unpinned_depth)
    assert_equal(unpinned_depth, 0)

    var depth = 0
    var guard = DepthGuard(depth)
    assert_equal(depth, 1)
    deinit(guard^)
    assert_equal(depth, 0)
