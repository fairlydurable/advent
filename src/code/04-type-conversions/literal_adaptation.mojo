# Claim: literals take their type from context: an integer literal can become
# Float64, and a scalar literal splats across every SIMD lane.
# Claim: a String converts implicitly to a StringSpan borrow, and a string
# literal converts implicitly to an owned String.
from std.testing import assert_equal


def label_bytes(label: StringSpan) -> Int:
    return label.byte_length()


def owned_bytes(label: String) -> Int:
    return label.byte_length()


def main() raises:
    var ratio: Float64 = 3
    assert_equal(ratio, 3.0)
    var mask: SIMD[DType.uint8, 4] = 7
    assert_equal(mask, SIMD[DType.uint8, 4](7, 7, 7, 7))
    var device = String("nvme0n1")
    assert_equal(label_bytes(device), 7)
    assert_equal(owned_bytes("eth0"), 4)
