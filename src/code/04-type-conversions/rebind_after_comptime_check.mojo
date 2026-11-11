# Claim: rebind tells the compiler two type expressions match after
# instantiation. Inside `comptime if width == 4`, SIMD[int32, width] and
# SIMD[int32, 4] are the same type, but the checker needs rebind to accept it.
from std.testing import assert_equal


def as_quad[width: SIMDLength](lanes: SIMD[DType.int32, width]) -> SIMD[DType.int32, 4]:
    comptime if width == 4:
        return rebind[SIMD[DType.int32, 4]](lanes)
    else:
        return SIMD[DType.int32, 4](0)


def main() raises:
    var quad = SIMD[DType.int32, 4](10, 20, 30, 40)
    assert_equal(as_quad(quad), quad)
    assert_equal(as_quad(SIMD[DType.int32, 2](10, 20)), SIMD[DType.int32, 4](0))
