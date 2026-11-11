# EXPECT-ERROR: offset_from rejects zero-sized pointee types at compile time, because every element sits at the same address
# EXPECT-MATCH: non-zero-sized pointee
# Claim: element distance is byte distance divided by size_of[T](), which
# has no meaning when the size is zero, so the call fails to compile.

from std.memory import Layout, alloc, dealloc


struct Visited(Movable):
    def __init__(out self):
        pass


def main():
    var markers = alloc(Layout[Visited](length=10))
    var base = markers.unsafe_ptr()
    print(base.unsafe_offset(3).offset_from(base))
    dealloc(markers^)
