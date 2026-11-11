# EXPECT-ERROR: a pointer from unsafe_ptr() borrows from its Allocation and dies with it
# EXPECT-MATCH: uninitialized value 'frames'
# Claim: reading through a pointer after `dealloc` is a compile-time error,
# because the pointer's origin is the `Allocation` itself.
from std.memory import alloc, dealloc, Layout


def main():
    var frames = alloc(Layout[UInt8](length=4096))
    var first_byte = frames.unsafe_ptr()
    first_byte.write(0x7F)
    dealloc(frames^)
    print(first_byte[])
