# Claim: a struct can stay linear instead of writing `__deinit__`: declare
# it `not Deinitable` and give it a named method that takes `deinit self`.
# Every owner must then call that method on every path.
# Claim: the `else` string on the conformance becomes the guidance in the
# compiler's message when an owner forgets.
from std.memory import alloc, dealloc, Allocation, Layout
from std.testing import assert_equal


struct FrameBuffer(
    not Deinitable else "call present() or discard() on a FrameBuffer"
):
    var _pixels: Allocation[UInt32]

    def __init__(out self, pixel_count: Int):
        self._pixels = alloc(Layout[UInt32](length=pixel_count))
        for index in range(pixel_count):
            self._pixels.unsafe_ptr().unsafe_offset(index).write(0xFF000000)

    def present(deinit self) -> UInt32:
        var corner = self._pixels.unsafe_ptr()[]
        dealloc(self._pixels^)
        return corner

    def discard(deinit self):
        dealloc(self._pixels^)


def main() raises:
    var screen = FrameBuffer(640 * 480)
    var corner = screen^.present()
    assert_equal(corner, 0xFF000000)

    var scratch = FrameBuffer(64)
    scratch^.discard()
