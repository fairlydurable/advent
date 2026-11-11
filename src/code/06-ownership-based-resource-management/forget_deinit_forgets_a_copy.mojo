# Claims:
# - Passing an ImplicitlyCopyable value to `forget_deinit` without `^`
#   forgets a fresh copy, not the original.
# - For ArcPointer, that copy holds a strong count, so forgetting it leaks
#   one reference: the payload can never reach a count of zero.
from std.memory import ArcPointer, forget_deinit
from std.testing import assert_equal


def main() raises:
    var config = ArcPointer(String("region=us-west-2"))
    assert_equal(config.count(), 1)

    forget_deinit(config)
    assert_equal(config.count(), 2)

    var spare = config
    forget_deinit(spare^)
    assert_equal(config.count(), 3)
