# Claim: a mutable Pointer converts implicitly to an immutable one, so you can
# pass it wherever an ImmPointer is expected.
# Claim: as_imm() makes the same conversion explicit.
from std.testing import assert_equal


def peek(reading: ImmPointer[Int, _]) -> Int:
    return reading[]


def main() raises:
    var pressure = 5500
    var gauge = Pointer(to=pressure)
    gauge[] += 100
    assert_equal(peek(gauge), 5600)
    assert_equal(peek(gauge.as_imm()), 5600)
