# SharedBox and SpinMutex together.
# Claims:
#   - Each thread receives its own SharedBox copy, moved into a slot it
#     takes ownership of. The copy dies on the worker thread, so
#     decrements happen concurrently with other threads' work.
#   - The mutex inside the box serializes the writes: the tally is exact.
#   - After every worker finishes, main holds the only remaining reference.
from threads import ThreadArg, spawn, join
from std.atomic import Atomic, Ordering, fence
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.os import abort
from std.testing import assert_equal

comptime WORKERS = 8


comptime MAX_REFCOUNT = UInt64(Int64.MAX)


struct SharedInner[T: Movable](not Movable):
    """The heap block every copy points at. It never moves once written."""
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        # The last SharedBox destroys the payload before it destroys the
        # block, so only the (uninitialized) storage is left to discard.
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
        # RELAXED is enough: the caller already holds a live copy, so the
        # count cannot reach zero while this increment is in flight.
        var previous = copy.inner[].strong.fetch_add[ordering=Ordering.RELAXED](1)
        if previous > MAX_REFCOUNT:
            abort("SharedBox reference count overflow")
        self.inner = copy.inner

    def __deinit__(deinit self):
        if self.inner[].strong.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
            return
        # Pairs with every other owner's RELEASE decrement: their writes to
        # the payload happen before the destruction below.
        fence[ordering=Ordering.ACQUIRE]()
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
        """Returns a mutable reference to the shared value. Synchronizing
        writes through it is the caller's job."""
        return (
            self.inner[]
            .payload.unsafe_ptr()
            .unsafe_origin_cast[self_origin.unsafe_mut_cast[True]()]()[]
        )

    def count(self) -> UInt64:
        return self.inner[].strong.load[ordering=Ordering.RELAXED]()
struct SpinMutex[T: Movable & Deinitable](Movable):
    var locked: Atomic[UInt8]
    var value: Self.T

    def __init__(out self, var value: Self.T):
        self.locked = Atomic[UInt8](0)
        self.value = value^

    def lock(mut self) -> MutexGuard[Self.T, origin_of(self)]:
        while True:
            var expected = UInt8(0)
            if self.locked.compare_exchange[
                success_ordering=Ordering.ACQUIRE,
                failure_ordering=Ordering.RELAXED,
                weak=True,
            ](expected, 1):
                return MutexGuard[Self.T, origin_of(self)](self)
            while self.locked.load[ordering=Ordering.RELAXED]() != 0:
                pass

    def try_lock(mut self) -> Optional[MutexGuard[Self.T, origin_of(self)]]:
        var expected = UInt8(0)
        if self.locked.compare_exchange[
            success_ordering=Ordering.ACQUIRE,
            failure_ordering=Ordering.RELAXED,
        ](expected, 1):
            return MutexGuard[Self.T, origin_of(self)](self)
        return None


struct MutexGuard[T: Movable & Deinitable, origin: MutOrigin](Movable):
    var mutex: Pointer[SpinMutex[Self.T], Self.origin]

    def __init__(out self, ref[Self.origin] mutex: SpinMutex[Self.T]):
        self.mutex = Pointer(to=mutex)

    def __getitem__(mut self) -> ref[self] Self.T:
        # Tie the returned reference to the guard, not to the mutex: the
        # guard stays alive, and the lock stays held, while it is in use.
        return Pointer(to=self.mutex[].value).unsafe_origin_cast[origin_of(self)]()[]

    def __deinit__(deinit self):
        self.mutex[].locked.store[ordering=Ordering.RELEASE](0)
def tally_votes(arg: ThreadArg) abi("C") -> ThreadArg:
    var slot = arg.unsafe_bitcast[SharedBox[SpinMutex[Int]]]()
    var tally = slot.unsafe_take_pointee()  # this thread owns its copy now
    for _ in range(2_500):
        var guard = tally[].lock()
        guard[] += 1
    return arg  # `tally` died at its last use above, on this thread


def main() raises:
    var tally = SharedBox(SpinMutex(0))
    var slots = alloc(Layout[SharedBox[SpinMutex[Int]]](length=WORKERS))
    var base = slots.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    for worker in range(WORKERS):
        base.unsafe_offset(worker).unsafe_write(tally.copy())
    var peak_count = tally.count()

    var handles = List[Int]()
    for worker in range(WORKERS):
        handles.append(spawn(tally_votes, base.unsafe_offset(worker).unsafe_bitcast[NoneType]()))
    for handle in handles:
        join(handle)
    dealloc(slots^)  # every worker moved its slot out; only the storage remains

    assert_equal(peak_count, WORKERS + 1)
    assert_equal(tally.count(), 1)
    assert_equal(tally[].value, WORKERS * 2_500)
