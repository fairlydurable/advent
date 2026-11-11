# EXPECT-ERROR: a struct with a linear field needs a destructor that consumes that field
# EXPECT-MATCH: non-'Deinitable' type
# Claim: holding an `Allocation` field makes the containing struct
# responsible for releasing it; without a `__deinit__` that consumes the
# field (or a `not Deinitable` declaration), the field itself is an error.
from std.memory import alloc, Allocation, Layout


struct FrameBuffer:
    var _pixels: Allocation[UInt32]

    def __init__(out self, pixel_count: Int):
        self._pixels = alloc(Layout[UInt32](length=pixel_count))


def main():
    var screen = FrameBuffer(1920 * 1080)
    print(len(screen._pixels))
