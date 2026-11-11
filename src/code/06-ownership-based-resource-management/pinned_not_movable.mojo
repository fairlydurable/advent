# Claims:
# - `not Movable` opts a struct out of relocation.
# - A non-Movable value can still transfer with `^` into a `var` argument
#   or a `deinit` method, because those consume it in place.
# - A function can return a freshly constructed non-Movable value.
from std.testing import assert_equal


struct SpinLockSlot(not Movable):
    var owner_id: Int

    def __init__(out self, owner_id: Int):
        self.owner_id = owner_id

    def release(deinit self) -> Int:
        return self.owner_id


def adopt(var slot: SpinLockSlot) -> Int:
    return slot.owner_id


def fresh_slot(owner_id: Int) -> SpinLockSlot:
    return SpinLockSlot(owner_id)


def main() raises:
    var slot = SpinLockSlot(41)
    assert_equal(adopt(slot^), 41)

    var made = fresh_slot(42)
    assert_equal(made^.release(), 42)
