# Claims:
#   - compare_exchange(expected, desired) stores `desired` only when the
#     current value equals `expected`, and returns whether it did.
#   - On failure it writes the value it actually saw back into `expected`,
#     which is why `expected` is a `mut` argument and why CAS loops never
#     need a separate reload.
from std.atomic import Atomic
from std.testing import assert_equal, assert_false, assert_true


def main() raises:
    var config_version = Atomic[UInt64](7)

    var expected = UInt64(7)
    assert_true(config_version.compare_exchange(expected, 8))
    assert_equal(config_version.load(), 8)

    expected = 7  # stale: another writer already moved it to 8
    assert_false(config_version.compare_exchange(expected, 9))
    assert_equal(expected, 8)  # refreshed with the value it observed
    assert_equal(config_version.load(), 8)  # unchanged
