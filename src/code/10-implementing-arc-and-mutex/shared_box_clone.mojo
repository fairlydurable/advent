# Cloning.
# Claims:
#   - The copy constructor bumps the count with a RELAXED fetch_add and
#     shares the pointer. No allocation, no payload copy.
#   - Copies see each other's writes because they share one payload.
#   - Copies die at their last use (ASAP), not at the end of the scope, so
#     the count falls as soon as a copy is no longer needed.
from std.atomic import Atomic, Ordering
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.os import abort
from std.testing import assert_equal

comptime MAX_REFCOUNT = UInt64(Int64.MAX)


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Copyable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, var value: Self.T):
        var block = alloc(Layout[SharedInner[Self.T]].single()).unsafe_leak()
        block.unsafe_write(
            init_with=lambda () -> SharedInner[Self.T]: SharedInner[Self.T]()
        )
        block[].payload.unsafe_write(value^)
        self.inner = block

    def __init__(out self, *, copy: Self):
        var previous = copy.inner[].strong.fetch_add[ordering=Ordering.RELAXED](1)
        if previous > MAX_REFCOUNT:
            abort("SharedBox reference count overflow")
        self.inner = copy.inner

    def __deinit__(deinit self):
        # Not yet thread-safe: section 10.1.4 adds the orderings.
        if self.inner[].strong.fetch_sub(1) != 1:
            return
        self.inner[].payload.unsafe_ptr().unsafe_deinit_pointee()
        self.inner.unsafe_deinit_pointee()
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.inner).unsafe_with_layout(
                Layout[SharedInner[Self.T]].single()
            )
        )

    def __getitem__[
        self_origin: ImmOrigin
    ](ref[self_origin] self) -> ref[self_origin.unsafe_mut_cast[True]()] Self.T:
        return (
            self.inner[]
            .payload.unsafe_ptr()
            .unsafe_origin_cast[self_origin.unsafe_mut_cast[True]()]()[]
        )

    def count(self) -> UInt64:
        return self.inner[].strong.load[ordering=Ordering.RELAXED]()


def main() raises:
    var session_ids: List[Int] = [4471, 4472]
    var sessions = SharedBox(session_ids^)
    var audit_view = sessions.copy()
    var cache_view = sessions.copy()
    assert_equal(sessions.count(), 3)

    cache_view[].append(4480)  # last use of `cache_view`
    assert_equal(sessions.count(), 2)
    assert_equal(len(audit_view[]), 3)  # last use of `audit_view`
    assert_equal(sessions.count(), 1)
