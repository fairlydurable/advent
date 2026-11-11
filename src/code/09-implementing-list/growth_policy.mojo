# Claims:
# - An empty MyList owns no heap memory: capacity 0 and a dangling pointer.
# - Growth doubles: pushing five elements walks capacity through 1, 2, 4, 8.
# - The dangling placeholder goes to unsafe_leak(), never to dealloc().

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


def main() raises:
    var cities = MyList[String]()
    assert_equal(cities.capacity(), 0)
    var dangling = Pointer[String, MutUntrackedOrigin].unsafe_dangling()
    assert_equal(Int(cities._storage.unsafe_ptr()), Int(dangling))

    var capacities = List[Int]()
    for city in ["Oslo", "Lima", "Pune", "Kyiv", "Graz"]:
        cities.push(city)
        capacities.append(cities.capacity())
    assert_equal(capacities, [1, 2, 4, 4, 8])
