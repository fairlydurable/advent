# Claims:
#   - When the guard's subscript returns a reference tied to the guard
#     (`ref[self]`), the guard lives as long as that reference is used, so
#     the lock flag reads 1 the whole time.
#   - After the reference's last use, the guard dies and the flag reads 0.
from std.atomic import Atomic, Ordering
from std.testing import assert_equal


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
def main() raises:
    var inventory = SpinMutex(250)
    var lock_flag = Pointer(to=inventory.locked).unsafe_origin_cast[MutUntrackedOrigin]()
    var guard = inventory.lock()
    ref stock = guard[]
    var flag_while_in_use = lock_flag[].load()
    stock -= 40  # last use of `stock`, and so of `guard`
    var flag_after = lock_flag[].load()
    assert_equal(flag_while_in_use, 1)
    assert_equal(flag_after, 0)
    assert_equal(inventory.value, 210)
