# Claims:
# - as_c_string_span() returns a CStringSpan whose origin is the String, so
#   the String stays alive while C reads it.
# - strlen() counts bytes up to the first zero; byte_length() counts the
#   String's bytes. They differ when the String contains a zero byte.
# - String(unsafe_from_utf8_ptr=) copies up to the first zero byte.
# - snprintf is variadic: num_fixed_args tells external_call how many
#   leading arguments are fixed, which matters on ABIs that pass variadic
#   arguments differently (arm64 macOS passes them on the stack).

from std.ffi import c_char, c_double, c_int, c_size_t, external_call
from std.testing import assert_equal


def main() raises:
    var sensor = String("probe-7")
    var span = sensor.as_c_string_span()
    assert_equal(external_call["strlen", c_size_t](span), 7)

    var with_nul = String("probe\0seven")
    assert_equal(with_nul.byte_length(), 11)
    assert_equal(external_call["strlen", c_size_t](with_nul.as_c_string_span()), 5)

    var buffer = Array[c_char, 64](fill=0)
    # int snprintf(char *buf, size_t size, const char *format, ...);
    var written = external_call["snprintf", c_int, num_fixed_args=3](
        buffer.unsafe_ptr(),
        c_size_t(len(buffer)),
        "%s reads %.1f C".as_c_string_span(),
        sensor.as_c_string_span(),
        c_double(21.5),
    )
    assert_equal(written, 20)
    assert_equal(String(unsafe_from_utf8_ptr=buffer.unsafe_ptr()), "probe-7 reads 21.5 C")
