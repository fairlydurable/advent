# Claims:
# - `unsafe_write(init_with=...)` constructs a value directly in raw memory,
#   so the type does not need to be Movable.
# - The value then lives at the allocation's address and nowhere else.
# - You end its lifetime in place with `unsafe_deinit_pointee()` before
#   releasing the storage.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal, assert_true


struct DeviceRegister(not Movable):
    var address: Int
    var value: UInt32

    def __init__(out self, address: Int):
        self.address = address
        self.value = 0


def main() raises:
    var storage = alloc(Layout[DeviceRegister].single())
    var slot = storage.unsafe_ptr()
    slot.unsafe_write(init_with=lambda () -> DeviceRegister: DeviceRegister(0x4000_1000))
    slot[].value = 0xFF
    # Read everything before releasing: `assert_*` can raise, and the
    # compiler rejects a raise while `storage` is still live.
    var address = slot[].address
    var value = slot[].value
    var emplaced_in_place = Int(Pointer(to=slot[])) == Int(storage.unsafe_ptr())
    slot.unsafe_deinit_pointee()
    dealloc(storage^)
    assert_equal(address, 0x4000_1000)
    assert_equal(value, 0xFF)
    assert_true(emplaced_in_place)
