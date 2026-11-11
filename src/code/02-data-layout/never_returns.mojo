# Claim: `Never` is the return type of a function that can't return. A call
# to it ends a path, so a function that must return a value can end a path
# with that call instead of a `return`.
from std.os import abort
from std.testing import assert_equal


def fail_closed(reason: StaticString) -> Never:
    abort(reason)


def checked_rpm(raw: Int) -> Int:
    if raw >= 0 and raw <= 12_000:
        return raw
    fail_closed("rpm sensor out of range")


def main() raises:
    assert_equal(checked_rpm(3600), 3600)
