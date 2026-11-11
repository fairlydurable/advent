# EXPECT-ERROR: a linear C file wrapper dropped without close() is a compile error
# EXPECT-MATCH: abandoned without being explicitly destroyed: call close
# Claim: an early return that forgets close() does not compile.

from std.ffi import c_int, external_call

# Spelled exactly as the standard library spells it: every external_call
# to one C symbol in a program must use the same Mojo types.
comptime FILE = Optional[MutOpaquePointer[MutUntrackedOrigin]]


struct CFile(Movable, not Deinitable else "call close() to release a CFile"):
    var _handle: FILE

    def __init__(out self, var path: String) raises:
        var handle = external_call["fopen", FILE](
            path.as_c_string_span(), "w".as_c_string_span()
        )
        if not handle:
            raise Error("fopen failed")
        self._handle = handle

    def close(deinit self) -> Bool:
        return external_call["fclose", c_int](self._handle) == 0


def log_reading(celsius: Float64) raises:
    var log = CFile("/tmp/mojonomicon_ffi.log")
    if celsius < -273.15:
        return  # forgot log^.close()
    _ = log^.close()


def main() raises:
    log_reading(21.5)
