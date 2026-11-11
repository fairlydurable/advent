# EXPECT-ERROR: dealloc consumes the Allocation, so a second dealloc reads a moved-from binding
# EXPECT-MATCH: use of uninitialized value 'frames'
# Claim: double free is a compile-time error for an `Allocation`.
from std.memory import alloc, dealloc, Layout


def main():
    var frames = alloc(Layout[UInt8](length=4096))
    dealloc(frames^)
    dealloc(frames^)
