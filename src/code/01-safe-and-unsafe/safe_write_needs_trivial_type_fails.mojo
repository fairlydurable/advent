# EXPECT-ERROR: the safe write() only accepts types with no destructor, since it may overwrite a live value
# EXPECT-MATCH: invalid call to 'write'
# Claim: `Pointer.write()` refuses `String`, whose overwritten value would
# leak; `unsafe_write()` is the spelling that accepts that responsibility.
from std.memory import alloc, dealloc, Layout


def main():
    var slot = alloc(Layout[String].single())
    slot.unsafe_ptr().write(String("calibrated"))
    slot.unsafe_ptr().unsafe_deinit_pointee()
    dealloc(slot^)
