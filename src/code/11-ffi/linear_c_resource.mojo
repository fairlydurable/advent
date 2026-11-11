# Claims:
# - A C resource whose release can fail (fclose reports write errors) fits a
#   linear type: no implicit destructor, only a named close() that returns
#   the status.
# - The compiler then rejects any path that drops the file without closing
#   it (see linear_c_resource_fails.mojo).

from std.ffi import c_char, c_int, external_call
from std.testing import assert_equal, assert_true

# Spelled exactly as the standard library spells it: every external_call
# to one C symbol in a program must use the same Mojo types.
comptime FILE = Optional[MutOpaquePointer[MutUntrackedOrigin]]


struct CFile(Movable, not Deinitable else "call close() to release a CFile"):
    var _handle: FILE

    def __init__(out self, var path: String, var mode: String) raises:
        # FILE *fopen(const char *path, const char *mode);
        var handle = external_call["fopen", FILE](
            path.as_c_string_span(), mode.as_c_string_span()
        )
        if not handle:
            raise Error("fopen failed")
        self._handle = handle

    def write(self, var line: String) -> Bool:
        # int fputs(const char *s, FILE *stream);
        return external_call["fputs", c_int](
            line.as_c_string_span(), self._handle
        ) >= 0

    def close(deinit self) -> Bool:
        # int fclose(FILE *stream);
        return external_call["fclose", c_int](self._handle) == 0


def main() raises:
    var log = CFile("/tmp/mojonomicon_ffi.log", "w")
    var wrote = log.write("calibration complete\n")
    var closed = log^.close()
    assert_true(wrote)
    assert_true(closed)
    # int remove(const char *path);
    assert_equal(
        external_call["remove", c_int]("/tmp/mojonomicon_ffi.log".as_c_string_span()),
        0,
    )
