# Claim: a leading underscore marks a field as internal by convention only.
# Code outside the struct can still read and write it, so a struct can't
# rely on field visibility to protect an invariant.
from std.testing import assert_equal


struct OdometerKm:
    var _reading: Int

    def __init__(out self):
        self._reading = 0

    def advance(mut self, distance: Int):
        if distance > 0:
            self._reading += distance


def main() raises:
    var odometer = OdometerKm()
    odometer.advance(120)
    odometer._reading = -40  # Compiles: nothing enforces the underscore.
    assert_equal(odometer._reading, -40)
