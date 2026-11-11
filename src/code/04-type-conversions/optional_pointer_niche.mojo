# Claim: Optional[Pointer[...]] has the same size as Pointer. The null address
# serves as the None niche, so nullability costs no extra storage.
from std.sys import size_of
from std.testing import assert_equal, assert_true


def main() raises:
    var pressure = 5500
    comptime GaugePointer = Pointer[Int, origin_of(pressure)]
    assert_equal(size_of[Optional[GaugePointer]](), size_of[GaugePointer]())
    var missing: Optional[GaugePointer] = None
    assert_true(not missing)
    var present: Optional[GaugePointer] = Pointer(to=pressure)
    assert_equal(present.value()[], 5500)
