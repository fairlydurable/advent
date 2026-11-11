# The final SpinMutex.
# Claims:
#   - lock() spins until a compare_exchange flips the flag from 0 to 1 with
#     ACQUIRE; the guard's deinitializer stores 0 with RELEASE. Everything
#     one holder wrote is visible to the next holder.
#   - Between attempts, the loop polls with plain RELAXED loads, so waiting
#     threads read a shared cache line instead of fighting over it.
#   - The guard's reference is tied to the guard, so the lock stays held
#     while that reference is in use.
#   - 8 threads x 10,000 locked increments of a plain Int total exactly 80,000.
#   - try_lock() fails while a guard is live and succeeds after it dies.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering
from std.testing import assert_equal, assert_true


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


def add_shipments(arg: ThreadArg) abi("C") -> ThreadArg:
    var mutex = arg.unsafe_bitcast[SpinMutex[Int]]()
    for _ in range(10_000):
        var guard = mutex[].lock()
        guard[] += 1  # last use of `guard`: unlocks right after this line
    return arg


def main() raises:
    var shipped = SpinMutex(0)
    run_threads(add_shipments, erase(shipped), 8)
    assert_equal(shipped.value, 80_000)

    var held = shipped.lock()
    var blocked = shipped.try_lock()
    var blocked_while_held = not Bool(blocked)
    held[] += 1  # last use of `held`: unlocks here
    var free_again = Bool(shipped.try_lock())
    assert_true(blocked_while_held)
    assert_true(free_again)
    assert_equal(shipped.value, 80_001)
