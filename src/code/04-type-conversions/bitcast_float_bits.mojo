# Claim: bitcast reinterprets the bits of a SIMD value as another dtype of the
# same total width; no numeric conversion happens.
# Claim: a round trip through bitcast restores the original value exactly.
from std.memory import bitcast
from std.testing import assert_equal


def main() raises:
    var gain = Float32(1.0)
    var bits = bitcast[DType.uint32](gain)
    assert_equal(bits, 0x3F800000)  # sign 0, exponent 127, mantissa 0
    var negative = bitcast[DType.uint32](Float32(-0.0))
    assert_equal(negative, 0x80000000)  # only the sign bit
    assert_equal(bitcast[DType.float32](bits), gain)
