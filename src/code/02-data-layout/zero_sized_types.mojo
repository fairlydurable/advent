# Claim: a struct with no fields occupies zero bytes, with alignment 1.
# Claim: an Array of a thousand of them also occupies zero bytes.
# Claim: zero-sized fields take no space; adjacent ones share an address,
# and a trailing one sits at the end of the struct.
from std.sys import size_of, align_of
from std.testing import assert_equal, assert_true


struct Unit:
    def __init__(out self):
        pass


@fieldwise_init
struct Measurement:
    var unit_before: Unit
    var millivolts: Int32
    var unit_after: Unit


def main() raises:
    assert_equal(size_of[Unit](), 0)
    assert_equal(align_of[Unit](), 1)
    assert_equal(size_of[Array[Unit, 1000]](), 0)
    assert_equal(size_of[Measurement](), 4)

    var reading = Measurement(Unit(), 3300, Unit())
    var base = Int(Pointer(to=reading))
    assert_equal(Int(Pointer(to=reading.unit_before)) - base, 0)
    assert_equal(Int(Pointer(to=reading.millivolts)) - base, 0)
    assert_equal(Int(Pointer(to=reading.unit_after)) - base, 4)
