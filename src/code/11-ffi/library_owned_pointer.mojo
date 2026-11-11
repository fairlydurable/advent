# Claims:
# - A pointer that a library returns into its own static data is valid only
#   while the library stays loaded.
# - Typing the result with the handle's origin keeps the handle alive for as
#   long as the pointer lives, with no manual keep-alive.
# - String(unsafe_from_utf8_ptr=) copies the bytes, after which the copy
#   outlives the library.

from std.ffi import OwnedDLHandle, c_char
from std.sys.info import platform_map
from std.testing import assert_true

comptime LIBZ = platform_map["libz", linux="libz.so.1", macos="libz.dylib"]()


def zlib_version() raises -> String:
    var zlib = OwnedDLHandle(LIBZ)
    comptime borrowed_from_zlib = ImmOrigin(origin_of(zlib))
    # const char *zlibVersion(void);  (points into libz itself)
    var version_fn = zlib.get_function[Pointer[c_char, borrowed_from_zlib]](
        "zlibVersion"
    )
    var version = version_fn()
    return String(unsafe_from_utf8_ptr=version)  # copy before zlib closes


def main() raises:
    var version = zlib_version()
    assert_true(version.startswith("1."))
