# Claims:
# - Pointer cannot be null; Optional[Pointer] models a nullable C pointer.
# - Optional[Pointer] has the same size as a pointer: None is the null
#   address, so it passes to and from C unchanged.
# - Passing None where C expects a pointer passes NULL.
# - A C function that can return NULL gets an Optional return type.

from std.ffi import c_char, external_call
from std.sys import size_of
from std.testing import assert_equal, assert_false, assert_true

comptime time_t = Int64


def main() raises:
    assert_equal(
        size_of[Optional[Pointer[Int64, MutUntrackedOrigin]]](),
        size_of[Pointer[Int64, MutUntrackedOrigin]](),
    )

    # time_t time(time_t *tloc);  tloc may be NULL
    var no_slot: Optional[Pointer[time_t, MutUntrackedOrigin]] = None
    var now = external_call["time", time_t](no_slot)
    assert_true(now > 1_700_000_000)

    # char *getenv(const char *name);  NULL when unset
    var missing = external_call[
        "getenv", Optional[Pointer[c_char, ImmUntrackedOrigin]]
    ]("MOJONOMICON_UNSET_VARIABLE".as_c_string_span())
    assert_false(Bool(missing))

    var path = external_call[
        "getenv", Optional[Pointer[c_char, ImmUntrackedOrigin]]
    ]("PATH".as_c_string_span())
    if path:
        assert_true(String(unsafe_from_utf8_ptr=path.value()).byte_length() > 0)
