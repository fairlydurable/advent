# Claim: `SIMD[DType.float32, 4]` and `Array[Float32, 4]` both hold 16 bytes,
# but SIMD aligns to its full width while Array aligns like its element.
# Claim: that difference changes the size of a struct that contains them.
from std.sys import size_of, align_of
from std.testing import assert_equal


struct VectorSample:
    var quality: UInt8
    var components: SIMD[DType.float32, 4]

    def __init__(out self):
        self.quality = 0
        self.components = SIMD[DType.float32, 4](0)


struct ArraySample:
    var quality: UInt8
    var components: Array[Float32, 4]

    def __init__(out self):
        self.quality = 0
        self.components = Array[Float32, 4](fill=0)


def main() raises:
    assert_equal(size_of[SIMD[DType.float32, 4]](), 16)
    assert_equal(align_of[SIMD[DType.float32, 4]](), 16)
    assert_equal(size_of[Array[Float32, 4]](), 16)
    assert_equal(align_of[Array[Float32, 4]](), 4)
    assert_equal(size_of[VectorSample](), 32)
    assert_equal(size_of[ArraySample](), 20)
    assert_equal(align_of[SIMD[DType.float64, 8]](), 64)
