# Claim: `Pointer.write()` is safe for trivially deinitializable types, so
# writing over a live `Int` twice is fine: there is no destructor to skip.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


def main() raises:
    var slot = alloc(Layout[Int].single())
    var cell = slot.unsafe_ptr()
    cell.write(1450)
    cell.write(1475)
    var stored = cell[]
    dealloc(slot^)
    assert_equal(stored, 1475)
