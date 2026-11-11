# Claim (3.9): without a later use, a guard dies right after construction.
# This is the ASAP rule that makes `deinit(guard^)` necessary.
from std.testing import assert_equal


struct Guard[o: MutOrigin](Movable):
    var counter: Pointer[Int, Self.o]

    def __init__(out self, ref[Self.o] counter: Int):
        self.counter = Pointer(to=counter)

    def __deinit__(deinit self):
        self.counter[] += 1


def main() raises:
    var released = 0
    _ = Guard(released)
    assert_equal(released, 1)
