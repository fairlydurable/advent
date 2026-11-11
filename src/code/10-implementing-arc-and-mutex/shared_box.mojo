# The final SharedBox: an atomically reference-counted heap box.
# Claims:
#   - Copies share one heap block; count() reports the live copies.
#   - Clone increments with RELAXED; drop decrements with RELEASE, and the
#     last owner issues an ACQUIRE fence before destroying the payload.
#   - The payload's deinitializer runs exactly once, on the last drop, and
#     the block is freed right after it.
#   - Copies and drops from 8 threads at once leave the count exact.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering, fence
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.os import abort
from std.testing import assert_equal

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


struct DropLog(Movable):
    """A payload that records its own destruction in a log owned by main()."""
    var label: String
    var log: Pointer[List[String], MutUntrackedOrigin]

    def __init__(out self, label: String, log: Pointer[List[String], MutUntrackedOrigin]):
        self.label = label
        self.log = log

    def __deinit__(deinit self):
        self.log[].append(String(self.label, " destroyed"))


def churn_copies(arg: ThreadArg) abi("C") -> ThreadArg:
    ref shared = arg.unsafe_bitcast[SharedBox[DropLog]]()[]
    for _ in range(10_000):
        var local = shared.copy()  # +1 here, -1 at its last use
        _ = local.count()
    return arg


def main() raises:
    var log = List[String]()
    var log_ptr = Pointer(to=log).unsafe_origin_cast[MutUntrackedOrigin]()

    var config = SharedBox(DropLog("config", log_ptr))
    var reader = config.copy()
    assert_equal(config.count(), 2)
    assert_equal(reader[].label, "config")  # last use of `reader`
    assert_equal(config.count(), 1)

    run_threads(churn_copies, erase(config), 8)
    assert_equal(config.count(), 1)
    assert_equal(len(log), 0)  # payload still alive

    deinit(config^)  # last owner: destroys the payload, frees the block
    assert_equal(log, ["config destroyed"])
