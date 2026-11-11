# Claim: MaybeUninit[T]() starts uninitialized; unsafe_write() fills it.
# Claim: unsafe_assume_init() on a reference borrows the value; called on an
# owned MaybeUninit (`slot^`) it moves the value out and ends the wrapper.
from std.memory import MaybeUninit
from std.testing import assert_equal


def main() raises:
    var slot = MaybeUninit[String]()
    slot.unsafe_write(String("payload"))
    var length = slot.unsafe_assume_init().byte_length()
    var owned = slot^.unsafe_assume_init()  # resolve the wrapper before raising
    assert_equal(length, 7)
    assert_equal(owned, "payload")
