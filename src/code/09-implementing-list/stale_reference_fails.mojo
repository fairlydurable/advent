# EXPECT-ERROR: an element reference held across push is invalidated, because push may reallocate the buffer
# EXPECT-MATCH: use of invalidated interior reference
# Claim: with an interior origin on __getitem__, any mutation of the list
# invalidates outstanding element references, so a stale reference into a
# freed buffer cannot compile.

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


def main():
    var cities = MyList[String]()
    cities.push("Oslo")
    ref first = cities[0]
    cities.push("Lima")  # may move every element to a new buffer
    print(first)
