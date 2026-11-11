# Claims:
# - RawBuffer owns an allocation and knows nothing about which slots hold
#   live values; it is a linear type with a named destructor, release().
# - A struct that owns a RawBuffer can still be Deinitable: its __deinit__
#   decides what to destroy, then consumes the buffer with release().
# - A struct does not need Copyable for its buffer to move with it.

from std.memory import (
    Allocation,
    Layout,
    ThinAllocation,
    alloc,
    dealloc,
    unsafe_destroy_n,
    unsafe_uninit_move_n,
)
from std.sys import size_of
from std.testing import assert_equal


struct RawBuffer[T: AnyType](Movable, not Deinitable):
    var _storage: Allocation[Self.T]

    def __init__(out self):
        self._storage = ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))

    def capacity(self) -> Int:
        comptime if size_of[Self.T]() == 0:
            return Int.MAX
        return len(self._storage)

    def ptr[origin: Origin, //](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    def grow(mut self, live: Int) where conforms_to(Self.T, Movable):
        var fresh = alloc(Layout[Self.T](length=max(1, self.capacity() * 2)))
        unsafe_uninit_move_n[overlapping=False](
            dest=fresh.unsafe_ptr(), src=self._storage.unsafe_ptr(), count=live
        )
        var old = self._storage^
        self._storage = fresh^
        Self._release(old^)

    @staticmethod
    def _release(var storage: Allocation[Self.T]):
        if len(storage) > 0:
            dealloc(storage^)
        else:
            _ = storage^.unsafe_leak()

    def release(deinit self):
        Self._release(self._storage^)


struct Stack[T: Movable & Deinitable](Movable):
    var _buf: RawBuffer[Self.T]
    var _len: Int

    def __init__(out self):
        self._buf = RawBuffer[Self.T]()
        self._len = 0

    def push(mut self, var value: Self.T):
        if self._len == self._buf.capacity():
            self._buf.grow(self._len)
        self._buf.ptr().unsafe_offset(self._len).unsafe_write(value^)
        self._len += 1

    def pop(mut self) -> Self.T:
        self._len -= 1
        return self._buf.ptr().unsafe_offset(self._len).unsafe_take_pointee()

    def __deinit__(deinit self):
        unsafe_destroy_n(self._buf.ptr(), self._len)
        self._buf^.release()


def main() raises:
    var routes = Stack[String]()
    for hop in ["gateway", "edge", "core", "origin"]:
        routes.push(hop)
    var moved = routes^  # the buffer travels with the stack
    assert_equal(moved.pop(), "origin")
    assert_equal(moved._buf.capacity(), 4)
