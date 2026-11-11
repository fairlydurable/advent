# Claims:
#   - If the guard's subscript returns a reference with the MUTEX's origin,
#     the reference no longer keeps the guard alive. The guard dies at its
#     own last use (the subscript call) and unlocks while the caller still
#     holds the reference.
#   - In one thread that only shows up as a flag reading 0. With threads it
#     is a data race, which is why the final MutexGuard ties the reference
#     to itself.
from std.atomic import Atomic, Ordering
from std.testing import assert_equal


struct SpinMutex[T: Movable & Deinitable](Movable):
    var locked: Atomic[UInt8]
    var value: Self.T

    def __init__(out self, var value: Self.T):
        self.locked = Atomic[UInt8](0)
        self.value = value^

    def lock(mut self) -> LooseGuard[Self.T, origin_of(self)]:
        var expected = UInt8(0)
        while not self.locked.compare_exchange[
            success_ordering=Ordering.ACQUIRE,
            failure_ordering=Ordering.RELAXED,
            weak=True,
        ](expected, 1):
            expected = 0
        return LooseGuard[Self.T, origin_of(self)](self)


struct LooseGuard[T: Movable & Deinitable, origin: MutOrigin](Movable):
    var mutex: Pointer[SpinMutex[Self.T], Self.origin]

    def __init__(out self, ref[Self.origin] mutex: SpinMutex[Self.T]):
        self.mutex = Pointer(to=mutex)

    def __getitem__(ref self) -> ref[Self.origin] Self.T:
        # The reference outlives nothing it should: its origin is the mutex.
        return Pointer(to=self.mutex[].value).unsafe_origin_cast[Self.origin]()[]

    def __deinit__(deinit self):
        self.mutex[].locked.store[ordering=Ordering.RELEASE](0)


def main() raises:
    var inventory = SpinMutex(250)
    var lock_flag = Pointer(to=inventory.locked).unsafe_origin_cast[MutUntrackedOrigin]()
    var guard = inventory.lock()
    ref stock = guard[]  # last use of `guard`: it unlocks right here
    var flag_while_in_use = lock_flag[].load()
    stock -= 40
    assert_equal(flag_while_in_use, 0)  # unlocked too early
    assert_equal(inventory.value, 210)
