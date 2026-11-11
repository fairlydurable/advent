# Claim: `Pointer(to=value)` and `ptr[]` are safe operations; the pointer
# carries the origin of `value`, and writes through it reach the original.
# Claim: a live pointer keeps its target alive, so ASAP destruction waits.
from std.testing import assert_equal


def main() raises:
    var pressure_kpa = 101
    var gauge = Pointer(to=pressure_kpa)
    gauge[] += 4
    assert_equal(pressure_kpa, 105)

    var station = String("north-ridge")
    var label = Pointer(to=station)
    # `station` has no direct use below, but `label` refers to it, so
    # `station` stays alive until `label`'s last use.
    assert_equal(label[], "north-ridge")
