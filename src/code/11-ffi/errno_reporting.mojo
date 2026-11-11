# Claims:
# - C functions report the reason for a failure through errno, which
#   get_errno() reads.
# - Read errno right after the failing call and only when the call's own
#   return value says it failed; a later successful call may change it.
# - set_errno() writes errno, which lets code clear it before a call whose
#   return value cannot signal failure on its own.

from std.ffi import ErrNo, c_int, external_call, get_errno, set_errno
from std.testing import assert_equal, assert_false, assert_true

comptime FILE = Optional[MutOpaquePointer[MutUntrackedOrigin]]


def open_config(var path: String) raises -> FILE:
    # FILE *fopen(const char *path, const char *mode);
    var file = external_call["fopen", FILE](
        path.as_c_string_span(), "r".as_c_string_span()
    )
    if not file:
        raise Error("cannot open ", path, ": ", get_errno())
    return file


def main() raises:
    var missing = external_call["fopen", FILE](
        "/no/such/dir/sensors.conf".as_c_string_span(), "r".as_c_string_span()
    )
    assert_false(Bool(missing))
    assert_true(get_errno() == ErrNo.ENOENT)

    set_errno(ErrNo.SUCCESS)
    assert_true(get_errno() == ErrNo.SUCCESS)

    var failed = False
    try:
        _ = open_config("/no/such/dir/sensors.conf")
    except e:
        failed = True
        assert_true(String(e).startswith("cannot open"))
    assert_true(failed)
