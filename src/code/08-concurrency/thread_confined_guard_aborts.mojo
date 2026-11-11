# EXPECT-EXIT: nonzero
# Claims:
#   - The same runtime guard stops the program when another thread touches
#     the value: the worker thread's call aborts the whole process.
from threads import ThreadArg, erase, spawn, join
from std.ffi import external_call, c_int
from std.os import abort


def current_thread() -> Int:
    return external_call["pthread_self", Int]()


struct FrameRecorder(Movable):
    var owner: Int
    var draw_calls: Int

    def __init__(out self):
        self.owner = current_thread()
        self.draw_calls = 0

    def record_draw(mut self):
        if external_call["pthread_equal", c_int](self.owner, current_thread()) == 0:
            abort("FrameRecorder used off its owning thread")
        self.draw_calls += 1


def draw_from_worker(arg: ThreadArg) abi("C") -> ThreadArg:
    arg.unsafe_bitcast[FrameRecorder]()[].record_draw()
    return arg


def main():
    var recorder = FrameRecorder()
    join(spawn(draw_from_worker, erase(recorder)))
    print(recorder.draw_calls)
