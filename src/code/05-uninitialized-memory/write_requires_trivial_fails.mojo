# EXPECT-ERROR: the safe write() refuses a type with a real destructor
# EXPECT-MATCH: invalid call to 'write': violated constraint
# Claim: Pointer.write() only accepts trivially deinitializable types, because
# overwriting a live value of any other type would skip its destructor. For
# String, use unsafe_write() into uninitialized memory instead.
from std.memory import alloc, dealloc, Layout


def main():
    var allocation = alloc(Layout[String](length=1))
    var slot = allocation.unsafe_ptr()
    slot.write(String("payload"))
    dealloc(allocation^)
