# Claims:
# - Memory C allocates (strdup, malloc) belongs to C's allocator and goes
#   back through free(), never through dealloc().
# - Wrapping the C pointer in a Deinitable struct ties free() to Mojo's
#   destruction, so the release happens exactly once at the last use.
# - String(unsafe_from_utf8_ptr=) copies, so the Mojo String outlives the
#   C buffer.
# - as_c_string_span() takes `mut self` (it may append the zero byte), so it
#   needs a named String, not a temporary.

from std.ffi import c_char, external_call
from std.memory import ArcPointer
from std.testing import assert_equal


struct CString(Movable):
    """Owns a NUL-terminated string allocated by C's malloc."""

    var _ptr: Pointer[c_char, MutUntrackedOrigin]
    var _frees: ArcPointer[Int]  # counts free() calls for the test

    def __init__(out self, var text: String, frees: ArcPointer[Int]) raises:
        # char *strdup(const char *s);
        var copy = external_call[
            "strdup", Optional[Pointer[c_char, MutUntrackedOrigin]]
        ](text.as_c_string_span())
        if not copy:
            raise Error("strdup failed")
        self._ptr = copy.value()
        self._frees = frees

    def to_string(self) -> String:
        return String(unsafe_from_utf8_ptr=self._ptr)

    def __deinit__(deinit self):
        external_call["free", NoneType](self._ptr)
        self._frees[] += 1


def main() raises:
    var frees = ArcPointer(0)
    var label = CString("rack-12/slot-3", frees)
    var copy = label.to_string()
    assert_equal(frees[], 1)  # `label` died at its last use, above
    assert_equal(copy, "rack-12/slot-3")
