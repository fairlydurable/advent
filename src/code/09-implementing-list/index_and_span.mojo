# Claims:
# - __getitem__ returns a reference into the heap buffer; assigning through
#   it mutates the element in place.
# - Two element references can be live at once while nothing mutates the list.
# - as_span() hands out a bounds-carrying view whose origin is the list.

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
from std.collections import check_bounds
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


    # Experimental: element references live in an interior origin, so any
    # mutation of the list invalidates them.
    comptime _Elements[origin: Origin] = origin._get_owned_interior["element"]

    def unsafe_ptr[
        origin: Origin, //
    ](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    @__unsafe_nested_origins_read_only
    def __getitem__(
        ref self, index: Int
    ) -> ref[Self._Elements[origin_of(self)]] Self.T:
        check_bounds(index, length=self._len)
        return self.unsafe_ptr().unsafe_offset(
            index
        )._get_ref_with_unsafe_interior_origin["element", origin_of(self)]()

    def as_span(ref self) -> Span[Self.T, origin_of(self)]:
        return Span(unsafe_ptr=self.unsafe_ptr(), length=self._len)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        unsafe_destroy_n(self._storage.unsafe_ptr(), self._len)
        Self._release(self._storage^)

    def deinit_with(deinit self, deinit_func: Some[def(var Self.T)], /):
        var data = self._storage.unsafe_ptr()
        for index in range(self._len):
            data.unsafe_offset(index).unsafe_deinit_pointee_with(deinit_func)
        Self._release(self._storage^)


def main() raises:
    var readings = MyList[Float64]()
    for celsius in [21.5, 22.0, 23.25]:
        readings.push(celsius)
    readings[1] = 22.75

    ref coldest = readings[0]
    ref warmest = readings[2]
    assert_equal(warmest - coldest, 1.75)

    var total = 0.0
    for reading in readings.as_span():
        total += reading
    assert_equal(total, 67.5)
