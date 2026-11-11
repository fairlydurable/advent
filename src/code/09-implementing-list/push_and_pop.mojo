# Claims:
# - push moves the value into uninitialized storage with unsafe_write.
# - pop moves the last value out with unsafe_take_pointee, which runs no
#   destructor; the value dies later, wherever its new owner dies.
# - Growth relocates elements without running their destructors.

from std.memory import (
    Allocation,
    ArcPointer,
    Layout,
    ThinAllocation,
    alloc,
    dealloc,
    unsafe_destroy_n,
    unsafe_uninit_move_n,
)
from std.testing import assert_equal, assert_true


struct MyList[T: AnyType](
    Movable,
    Sized,
    Deinitable where conforms_to(T, Deinitable) else (
        "a MyList of non-Deinitable elements needs an explicit"
        " deinit_with() call"
    ),
):
    var _storage: Allocation[Self.T]
    var _len: Int

    def __init__(out self):
        self._storage = Self._dangling()
        self._len = 0

    @staticmethod
    def _dangling() -> Allocation[Self.T]:
        return ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))

    @staticmethod
    def _release(var storage: Allocation[Self.T]):
        if len(storage) > 0:
            dealloc(storage^)
        else:
            _ = storage^.unsafe_leak()  # never came from the allocator

    def __len__(self) -> Int:
        return self._len

    def capacity(self) -> Int:
        return len(self._storage)

    def _grow(mut self) where conforms_to(Self.T, Movable):
        var fresh = alloc(Layout[Self.T](length=max(1, self.capacity() * 2)))
        unsafe_uninit_move_n[overlapping=False](
            dest=fresh.unsafe_ptr(),
            src=self._storage.unsafe_ptr(),
            count=self._len,
        )
        var old = self._storage^
        self._storage = fresh^
        Self._release(old^)

    def push(mut self, var value: Self.T) where conforms_to(Self.T, Movable):
        if self._len == self.capacity():
            self._grow()
        self._storage.unsafe_ptr().unsafe_offset(self._len).unsafe_write(
            value^
        )
        self._len += 1

    def pop(mut self) -> Optional[Self.T] where conforms_to(Self.T, Movable):
        if self._len == 0:
            return None
        self._len -= 1
        return self._storage.unsafe_ptr().unsafe_offset(
            self._len
        ).unsafe_take_pointee()

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        unsafe_destroy_n(self._storage.unsafe_ptr(), self._len)
        Self._release(self._storage^)

    def deinit_with(deinit self, deinit_func: Some[def(var Self.T)], /):
        var data = self._storage.unsafe_ptr()
        for index in range(self._len):
            data.unsafe_offset(index).unsafe_deinit_pointee_with(deinit_func)
        Self._release(self._storage^)


struct Tracked(Movable):
    """An element that counts its own destructions in a shared counter."""

    var id: Int
    var drops: ArcPointer[Int]

    def __init__(out self, id: Int, drops: ArcPointer[Int]):
        self.id = id
        self.drops = drops

    def __deinit__(deinit self):
        self.drops[] += 1


def main() raises:
    var drops = ArcPointer(0)
    var parts = MyList[Tracked]()
    for id in range(5):
        parts.push(Tracked(id, drops))  # grows three times along the way
    assert_equal(drops[], 0)

    var last = parts.pop()
    assert_equal(drops[], 0)  # moved out, not destroyed
    assert_equal(last.value().id, 4)
    assert_equal(drops[], 1)  # `last` died at its final use, the line above
    assert_equal(len(parts), 4)
