# Claim: constructing a narrower integer type keeps the low bits (two's
# complement wrap); it never saturates and never traps.
# Claim: constructing an unsigned type from a negative value reinterprets the
# bits, so -1 becomes the type's maximum.
# Claim: float-to-integer construction truncates toward zero, for negative
# values too.
from std.testing import assert_equal


def main() raises:
    var sample_count = 300
    assert_equal(UInt8(sample_count), 44)
    assert_equal(Int8(200), -56)
    var sentinel = -1
    assert_equal(UInt8(sentinel), 255)
    assert_equal(UInt64(sentinel), 18446744073709551615)
    assert_equal(Int(Float64(3.99)), 3)
    assert_equal(Int(Float64(-3.99)), -3)  # toward zero, not down
