# Base code: one owner, no copies yet.
# Claims:
#   - The box allocates its block with alloc(...).unsafe_leak(): from here
#     on, nothing tracks the allocation except the box's own deinitializer.
#   - The block is written in two phases: the non-Movable SharedInner is
#     built in place, then the payload moves into its MaybeUninit field.
#   - Destroying the box destroys the payload, then the block, then frees
#     the storage, in that order.
from std.atomic import Atomic, Ordering
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.testing import assert_equal


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Movable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, var value: Self.T):
        var block = alloc(Layout[SharedInner[Self.T]].single()).unsafe_leak()
        block.unsafe_write(
            init_with=lambda () -> SharedInner[Self.T]: SharedInner[Self.T]()
        )
        block[].payload.unsafe_write(value^)
        self.inner = block

    def __deinit__(deinit self):
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
    var routes: List[String] = ["10.0.0.0/8", "172.16.0.0/12"]
    var table = SharedBox(routes^)
    table[].append("192.168.0.0/16")
    assert_equal(len(table[]), 3)
    assert_equal(table.count(), 1)
