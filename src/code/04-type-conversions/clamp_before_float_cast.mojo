# Claim: the stdlib defines no result for a float lane outside the target
# integer range, so clamp into range first. After clamping, every lane casts
# to a defined value.
from std.testing import assert_equal


def main() raises:
    var brightness = SIMD[DType.float32, 4](-12.0, 0.4, 254.6, 300.7)
    var clamped = brightness.clamp(0.0, 255.0)
    assert_equal(clamped.cast[DType.uint8](), SIMD[DType.uint8, 4](0, 0, 254, 255))
