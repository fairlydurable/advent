# Claims:
#   - The type system has no notion of "this value must stay on one thread".
#     A type that needs that rule can enforce it at run time instead.
#   - pthread_self() identifies the calling thread; pthread_equal() compares
#     two thread IDs (POSIX does not promise that `==` on them is meaningful).
#   - Use from the owning thread passes the check.
from threads import ThreadArg
from std.ffi import external_call, c_int
from std.os import abort
from std.testing import assert_equal


def current_thread() -> Int:
    return external_call["pthread_self", Int]()


struct FrameRecorder(Movable):
    """Records draw calls. Its buffers are not synchronized, so only the
    thread that created it may use it."""
    var owner: Int
    var draw_calls: Int

    def __init__(out self):
        self.owner = current_thread()
        self.draw_calls = 0

    def record_draw(mut self):
        if external_call["pthread_equal", c_int](self.owner, current_thread()) == 0:
            abort("FrameRecorder used off its owning thread")
        self.draw_calls += 1


def main() raises:
    var recorder = FrameRecorder()
    for _ in range(3):
        recorder.record_draw()
    assert_equal(recorder.draw_calls, 3)
