# EXPECT-ERROR: a linear struct that no path consumes, reported with the type's own guidance
# EXPECT-MATCH: call present\(\) or discard\(\)
# Claim: forgetting the named destructor of a `not Deinitable` struct is a
# compile error, and the message carries the type author's text.
from std.memory import alloc, dealloc, Allocation, Layout


struct FrameBuffer(
    not Deinitable else "call present() or discard() on a FrameBuffer"
):
    var _pixels: Allocation[UInt32]

    def __init__(out self, pixel_count: Int):
        self._pixels = alloc(Layout[UInt32](length=pixel_count))

    def discard(deinit self):
        dealloc(self._pixels^)


def main():
    var screen = FrameBuffer(640 * 480)
    print(len(screen._pixels))
