# Claim: SIMD.cast converts every lane with the same rules as scalar
# construction: integer narrowing wraps, float to integer truncates toward
# zero.
# Claim: float narrowing rounds to the nearest representable value, so a round
# trip through Float32 can change a Float64.
from std.testing import assert_equal, assert_true


def main() raises:
    var offsets = SIMD[DType.int32, 4](255, 256, -1, 1000)
    assert_equal(offsets.cast[DType.uint8](), SIMD[DType.uint8, 4](255, 0, 255, 232))

    var gains = SIMD[DType.float32, 4](1.5, -2.5, 100.9, 0.2)
    assert_equal(gains.cast[DType.int32](), SIMD[DType.int32, 4](1, -2, 100, 0))

    var precise = Float64(123456789.123456789)
    var narrowed = Float64(Float32(precise))
    assert_equal(narrowed, 123456792.0)
    assert_true(narrowed != precise)
