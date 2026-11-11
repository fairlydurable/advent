# Claims:
# - external_call["name", ReturnType](args...) calls a C function that the
#   process already links (libc here), with no binding declarations.
# - C's int maps to c_int (Int32) and size_t to c_size_t (UInt).
# - A string literal passes to a const char* parameter through
#   as_c_string_span(), which guarantees a terminating zero byte.
# - A struct C returns by value must be RegisterPassable and must declare its
#   fields in C order.

from std.ffi import c_int, c_size_t, external_call
from std.testing import assert_equal


@fieldwise_init
struct DivT(RegisterPassable):  # C's div_t
    var quot: c_int
    var rem: c_int


def main() raises:
    # int abs(int);
    assert_equal(external_call["abs", c_int](c_int(-273)), 273)

    # size_t strlen(const char *);
    var length = external_call["strlen", c_size_t]("thermocouple".as_c_string_span())
    assert_equal(length, 12)

    # div_t div(int numerator, int denominator);
    var minutes = external_call["div", DivT](c_int(437), c_int(60))
    assert_equal(minutes.quot, 7)
    assert_equal(minutes.rem, 17)
