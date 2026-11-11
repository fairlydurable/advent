# Claim: a struct that owns raw storage keeps one invariant
# (`_count <= capacity`, and slots below `_count` hold live values), and
# every method relies on it. The checked methods are safe because they
# uphold it; `unsafe_set_count` is the one door that can break it, and its
# name says so.
# Claim: `__deinit__` destroys exactly the live elements, then releases the
# storage, so no element leaks and no element dies twice.
from std.memory import alloc, dealloc, unsafe_destroy_n, Allocation, ArcPointer, Layout
from std.testing import assert_equal, assert_false


struct BoundedStack[T: Movable & Deinitable](Sized):
    var _storage: Allocation[Self.T]
    var _count: Int

    def __init__(out self, capacity: Int):
        self._storage = alloc(Layout[Self.T](length=capacity))
        self._count = 0

    def __deinit__(deinit self):
        unsafe_destroy_n(self._storage.unsafe_ptr(), self._count)
        dealloc(self._storage^)

    def capacity(self) -> Int:
        return len(self._storage)

    def __len__(self) -> Int:
        return self._count

    def push(mut self, var value: Self.T) -> Bool:
        if self._count == self.capacity():
            return False  # `value` dies here, at its last use.
        self._storage.unsafe_ptr().unsafe_offset(self._count).unsafe_write(
            value^
        )
        self._count += 1
        return True

    def pop(mut self) -> Optional[Self.T]:
        if self._count == 0:
            return None
        self._count -= 1
        return self._storage.unsafe_ptr().unsafe_offset(
            self._count
        ).unsafe_take_pointee()

    def unsafe_set_count(mut self, count: Int):
        """Sets the element count without initializing or destroying.

        Safety: every slot below `count` must hold a live value, and every
        slot at or above it must not.
        """
        self._count = count


def main() raises:
    var config = ArcPointer(String("ttl=30"))
    var stack = BoundedStack[ArcPointer[String]](capacity=2)
    _ = stack.push(config.copy())
    _ = stack.push(config.copy())
    var accepted = stack.push(config.copy())
    assert_false(accepted)  # Full: the rejected share released at once.
    assert_equal(config.count(), 3)

    var top = stack.pop()
    assert_equal(len(stack), 1)
    _ = top^
    assert_equal(config.count(), 2)

    _ = stack^  # Destroys the one live element, then frees storage.
    assert_equal(config.count(), 1)
