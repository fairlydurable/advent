# Claims:
# - @export keeps a function's symbol name unmangled and visible in a
#   shared library built with `mojo build --emit shared-lib`.
# - abi("C") gives the function the C calling convention, so a C host can
#   call it through a plain function pointer.
# - An exported abi("C") function stays an ordinary Mojo function that Mojo
#   code can call directly.
# The C-host round trip appears in the chapter; this sample checks the
# Mojo side.

from std.ffi import c_double
from std.testing import assert_equal


@export
def celsius_to_kelvin(celsius: c_double) abi("C") -> c_double:
    return celsius + 273.15


def main() raises:
    assert_equal(celsius_to_kelvin(-273.15), 0.0)
