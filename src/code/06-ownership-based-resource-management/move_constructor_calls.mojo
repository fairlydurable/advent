# Claims:
# - The move constructor is `__init__(out self, *, deinit move: Self)`.
# - `var dest = source^` runs the move constructor.
# - Passing `source^` to a `var` argument hands over ownership without a move:
#   the callee owns the caller's storage.
# - `return local^` runs the move constructor.
# - A move never runs `__deinit__` on the source; the destination inherits
#   responsibility for destruction.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Frame(Copyable, Movable):
    var payload: String
    var moves: ArcPointer[Int]
    var deinits: ArcPointer[Int]

    def __init__(
        out self,
        payload: String,
        moves: ArcPointer[Int],
        deinits: ArcPointer[Int],
    ):
        self.payload = payload
        self.moves = moves
        self.deinits = deinits

    def __init__(out self, *, copy: Self):
        self.payload = copy.payload
        self.moves = copy.moves
        self.deinits = copy.deinits

    def __init__(out self, *, deinit move: Self):
        self.payload = move.payload^
        self.moves = move.moves^
        self.deinits = move.deinits^
        self.moves[] += 1

    def __deinit__(deinit self):
        self.deinits[] += 1


def consume(var frame: Frame) -> Int:
    return frame.payload.byte_length()


def build(moves: ArcPointer[Int], deinits: ArcPointer[Int]) -> Frame:
    var local = Frame("handshake", moves, deinits)
    return local^


def main() raises:
    var moves = ArcPointer(0)
    var deinits = ArcPointer(0)

    var first = Frame("syn", moves, deinits)
    var second = first^
    assert_equal(moves[], 1)
    assert_equal(deinits[], 0)

    _ = consume(second^)
    assert_equal(moves[], 1)
    assert_equal(deinits[], 1)

    var built = build(moves, deinits)
    assert_equal(moves[], 2)
    assert_equal(built.payload, "handshake")
