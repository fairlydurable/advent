# Claim (3.9): `deinit(value^)` moves the last use to that line, so a guard
# whose effect lives in its deinitializer acts there and not at construction.
from std.testing import assert_equal


struct Guard[o: MutOrigin](Movable):
    var counter: Pointer[Int, Self.o]

    def __init__(out self, ref[Self.o] counter: Int):
        self.counter = Pointer(to=counter)

    def __deinit__(deinit self):
        self.counter[] += 1


def main() raises:
    var released = 0
    var guard = Guard(released)
    assert_equal(released, 0)
    deinit(guard^)
    assert_equal(released, 1)
