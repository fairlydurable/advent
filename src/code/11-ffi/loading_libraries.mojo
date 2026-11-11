# Claims:
# - OwnedDLHandle(path) dlopens a library and dlcloses it in its destructor.
# - get_function[ReturnType](name) returns a callable that borrows the
#   handle, so the library cannot close between lookup and call.
# - A missing symbol raises an Error instead of aborting.
# - OwnedDLHandle() with no path opens the symbols already in the process.

from std.ffi import OwnedDLHandle, c_double, c_size_t
from std.sys.info import platform_map
from std.testing import assert_equal, assert_false, assert_raises, assert_true

comptime LIBM = platform_map["libm", linux="libm.so.6", macos="libm.dylib"]()


def main() raises:
    var libm = OwnedDLHandle(LIBM)
    assert_true(libm.check_symbol("hypot"))
    var hypot = libm.get_function[c_double]("hypot")
    assert_equal(hypot(c_double(3.0), c_double(4.0)), 5.0)

    assert_false(libm.check_symbol("hypotenuse_of_the_week"))
    with assert_raises(contains="symbol not found"):
        _ = libm.get_function[c_double]("hypotenuse_of_the_week")

    var process = OwnedDLHandle()
    var strlen = process.get_function[c_size_t]("strlen")
    assert_equal(strlen("Kelvin".as_c_string_span()), 6)
