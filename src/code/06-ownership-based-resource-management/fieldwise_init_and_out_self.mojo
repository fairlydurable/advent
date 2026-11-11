# Claims:
# - `@fieldwise_init` synthesizes an `__init__` that takes one argument per field.
# - `out self` names uninitialized storage; the constructor must initialize
#   every field before it returns.
# - A constructor can delegate by assigning a whole value to `self`.
# - Any function can name its result with `out`, and initializes it in place.
from std.testing import assert_equal


@fieldwise_init
struct Reading(Copyable):
    var sensor: String
    var celsius: Float64


struct Calibration(Movable):
    var offset: Float64
    var scale: Float64

    def __init__(out self, offset: Float64, scale: Float64):
        self.offset = offset
        self.scale = scale

    def __init__(out self):
        # Delegation: build a complete value and assign it to `self`.
        self = Self(offset=0.0, scale=1.0)


def zeroed_reading(sensor: String, out reading: Reading):
    reading = Reading(sensor, 0.0)


def main() raises:
    var reading = Reading("intake", 21.5)
    assert_equal(reading.sensor, "intake")

    var identity = Calibration()
    assert_equal(identity.scale, 1.0)

    var baseline = zeroed_reading("exhaust")
    assert_equal(baseline.celsius, 0.0)
