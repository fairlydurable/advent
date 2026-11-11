# EXPECT-ERROR: using the guard after moving the mutex counts as using the moved-out mutex
# EXPECT-MATCH: (cannot be consumed|uninitialized value 'inventory')
# Claims:
#   - The guard holds a Pointer whose origin is the mutex, so every use of
#     the guard is a use of the mutex. Moving the mutex out from under a
#     live guard makes the later guard use a use of a moved-out value, and
#     the compiler rejects it.
from std.atomic import Atomic, Ordering


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
def main():
    var inventory = SpinMutex(250)
    var guard = inventory.lock()
    var relocated = inventory^
    guard[] -= 40
    _ = relocated.value
