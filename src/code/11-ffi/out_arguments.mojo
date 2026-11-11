# Claims:
# - A C-style out argument takes Pointer(to=binding) of a Mojo value.
# - MaybeUninit[T] has T's layout, so C can initialize it through
#   unsafe_ptr() without a placeholder value first.
# - unsafe_assume_init() is the promise that C wrote the value; read it only
#   after checking C's status code.

from std.ffi import c_double, c_int, c_long, external_call
from std.memory import MaybeUninit
from std.sys import size_of
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Timespec(RegisterPassable):
    var tv_sec: Int64  # time_t
    var tv_nsec: c_long


comptime CLOCK_REALTIME = c_int(0)


def main() raises:
    # double frexp(double value, int *exponent);
    var exponent: c_int = 0
    var mantissa = external_call["frexp", c_double](
        c_double(48.0), Pointer(to=exponent)
    )
    assert_equal(mantissa, 0.75)
    assert_equal(exponent, 6)  # 48 = 0.75 * 2**6

    assert_equal(size_of[MaybeUninit[Timespec]](), size_of[Timespec]())
    var slot = MaybeUninit[Timespec]()
    # int clock_gettime(clockid_t clock, struct timespec *tp);
    var status = external_call["clock_gettime", c_int](
        CLOCK_REALTIME, slot.unsafe_ptr()
    )
    assert_equal(status, 0)
    ref now = slot.unsafe_assume_init()  # sound only because status was 0
    assert_true(now.tv_sec > 1_700_000_000)
    assert_true(now.tv_nsec >= 0 and now.tv_nsec < 1_000_000_000)
