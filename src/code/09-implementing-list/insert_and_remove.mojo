# Claims:
# - insert and remove shift the tail with unsafe_uninit_move_n, which
#   relocates elements and runs no destructors.
# - remove moves the element out and hands ownership to the caller.

from std.collections import check_bounds
from std.memory import (
    ArcPointer,
    Allocation,
    Layout,
    ThinAllocation,
    alloc,
    dealloc,
    forget_deinit,
    unsafe_destroy_n,
    unsafe_uninit_move_n,
)
from std.sys import size_of
from std.testing import assert_equal, assert_true


# ===--- RawBuffer: owns the allocation, knows nothing about elements ---=== #


struct RawBuffer[T: AnyType](Movable, not Deinitable):
    var _storage: Allocation[Self.T]

    def __init__(out self):
        # Capacity 0 never touches the allocator: a dangling, well-aligned
        # pointer stands in for storage.
        self._storage = ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))

    def capacity(self) -> Int:
        comptime if size_of[Self.T]() == 0:
            return Int.MAX  # zero-sized elements fit anywhere
        return len(self._storage)

    def ptr[origin: Origin, //](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    def grow(mut self, live: Int) where conforms_to(Self.T, Movable):
        var new_capacity = max(1, self.capacity() * 2)
        var fresh = alloc(Layout[Self.T](length=new_capacity))
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
            # The dangling placeholder never came from the allocator.
            _ = storage^.unsafe_leak()

    def release(deinit self):
        Self._release(self._storage^)


# ===--- MyList: tracks which slots hold live elements ---=== #


struct MyList[T: AnyType](
    Movable,
    Sized,
    Deinitable where conforms_to(T, Deinitable) else (
        "a MyList of non-Deinitable elements needs an explicit"
        " deinit_with() call"
    ),
):
    var _buf: RawBuffer[Self.T]
    var _len: Int

    # Experimental: element references live in an interior origin, so any
    # mutation of the list invalidates them.
    comptime _Elements[origin: Origin] = origin._get_owned_interior["element"]

    def __init__(out self):
        self._buf = RawBuffer[Self.T]()
        self._len = 0

    def __len__(self) -> Int:
        return self._len

    def capacity(self) -> Int:
        return self._buf.capacity()

    def unsafe_ptr[
        origin: Origin, //
    ](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._buf.ptr().unsafe_origin_cast[origin]()

    def push(mut self, var value: Self.T) where conforms_to(Self.T, Movable):
        if self._len == self.capacity():
            self._buf.grow(self._len)
        self._buf.ptr().unsafe_offset(self._len).unsafe_write(value^)
        self._len += 1

    def pop(mut self) -> Optional[Self.T] where conforms_to(Self.T, Movable):
        if self._len == 0:
            return None
        self._len -= 1
        return self._buf.ptr().unsafe_offset(self._len).unsafe_take_pointee()

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

    def insert(
        mut self, index: Int, var value: Self.T
    ) where conforms_to(Self.T, Movable):
        check_bounds(index, length=self._len + 1)
        if self._len == self.capacity():
            self._buf.grow(self._len)
        var data = self.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(index + 1),
            src=data.unsafe_offset(index),
            count=self._len - index,
        )
        data.unsafe_offset(index).unsafe_write(value^)
        self._len += 1

    def remove(mut self, index: Int) -> Self.T where conforms_to(Self.T, Movable):
        check_bounds(index, length=self._len)
        var data = self.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
        var removed = data.unsafe_offset(index).unsafe_take_pointee()
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(index),
            src=data.unsafe_offset(index + 1),
            count=self._len - index - 1,
        )
        self._len -= 1
        return removed^

    def drain(
        mut self, start: Int, end: Int
    ) -> Drain[Self.T, Self._Elements[origin_of(self)]] where conforms_to(
        Self.T, Movable & Deinitable
    ):
        return Drain(self, start, end)

    def __iter__(
        var self,
    ) -> IntoIter[Self.T] where conforms_to(Self.T, Movable & Deinitable):
        return IntoIter(self^)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        unsafe_destroy_n(self._buf.ptr(), self._len)
        self._buf^.release()

    def deinit_with(deinit self, deinit_func: Some[def(var Self.T)], /):
        var data = self._buf.ptr()
        for index in range(self._len):
            data.unsafe_offset(index).unsafe_deinit_pointee_with(deinit_func)
        self._buf^.release()


# ===--- IntoIter: owns the list, yields elements by value ---=== #


struct IntoIter[T: Movable & Deinitable](Iterator, Movable):
    comptime Element = Self.T
    var _list: MyList[Self.T]
    var _next: Int

    def __init__(out self, var list: MyList[Self.T]):
        self._list = list^
        self._next = 0

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.T:
        if self._next == len(self._list):
            raise StopIteration()
        self._next += 1
        return self._list.unsafe_ptr().unsafe_offset(
            self._next - 1
        ).unsafe_take_pointee()

    def __deinit__(deinit self):
        # Slots before _next already moved out; destroy only the rest, then
        # tell the list it holds nothing so its own destructor skips them.
        var data = self._list.unsafe_ptr()
        unsafe_destroy_n(
            data.unsafe_offset(self._next), len(self._list) - self._next
        )
        self._list._len = 0


# ===--- Drain: removes a range, closes the gap when destroyed ---=== #


struct Drain[T: Movable & Deinitable, origin: MutOrigin](Iterator, Movable):
    comptime Element = Self.T
    var _list: Pointer[MyList[Self.T], Self.origin]
    var _next: Int
    var _end: Int
    var _tail_len: Int

    def __init__[
        list_origin: MutOrigin, //
    ](
        out self: Drain[Self.T, list_origin._get_owned_interior["element"]],
        ref[list_origin] list: MyList[Self.T],
        start: Int,
        end: Int,
    ):
        check_bounds(start, length=end + 1)
        check_bounds(end, length=len(list) + 1)
        self._list = Pointer(
            to=Pointer(to=list)._get_ref_with_unsafe_interior_origin[
                "element", list_origin
            ]()
        )
        self._next = start
        self._end = end
        self._tail_len = len(list) - end
        # Leak amplification: from here until the drain is destroyed, the
        # list claims only the prefix. Leaking the drain leaks the range and
        # the tail, but never exposes a moved-out slot.
        list._len = start

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.T:
        if self._next == self._end:
            raise StopIteration()
        self._next += 1
        return self._list[].unsafe_ptr().unsafe_offset(
            self._next - 1
        ).unsafe_take_pointee()

    def __deinit__(deinit self):
        var data = self._list[].unsafe_ptr().unsafe_origin_cast[
            MutUntrackedOrigin
        ]()
        unsafe_destroy_n(data.unsafe_offset(self._next), self._end - self._next)
        var start = self._list[]._len
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(start),
            src=data.unsafe_offset(self._end),
            count=self._tail_len,
        )
        self._list[]._len = start + self._tail_len


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
    for id in range(4):
        parts.push(Tracked(id, drops))

    parts.insert(1, Tracked(40, drops))  # ids now 0, 40, 1, 2, 3
    assert_equal(parts[1].id, 40)
    assert_equal(parts[4].id, 3)

    var removed = parts.remove(0)  # ids now 40, 1, 2, 3
    assert_equal(parts[0].id, 40)
    assert_equal(drops[], 0)  # every shift was a relocation
    assert_equal(removed.id, 0)
    assert_equal(drops[], 1)  # `removed` died after its last use
    assert_equal(len(parts), 4)
