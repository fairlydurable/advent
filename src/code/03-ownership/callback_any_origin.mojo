# Claims (3.7):
# - A function-typed argument with a `mut` parameter accepts references with
#   any origin; the callee chooses which values it lends.
# - A closure lists its captures in `{}`; `mut calls` captures by mutable reference.
from std.testing import assert_equal


def apply_each(mut readings: List[Int], adjust: Some[def(mut Int) -> None]):
    for ref reading in readings:
        adjust(reading)


def main() raises:
    var readings: List[Int] = [3, 7]
    var calls = 0

    def offset(mut reading: Int) {mut calls}:
        reading += 100
        calls += 1

    apply_each(readings, offset)
    assert_equal(readings, [103, 107])
    assert_equal(calls, 2)
