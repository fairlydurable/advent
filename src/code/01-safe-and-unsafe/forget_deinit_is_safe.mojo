# Claim: `forget_deinit` is a safe function. Skipping a destructor can leak,
# but leaking never breaks memory safety, so no `unsafe_` prefix applies.
# Claim: it skips the destructors of the value's fields too.
from std.memory import forget_deinit, ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Replicas(Movable):
    var primary: ArcPointer[String]
    var backup: ArcPointer[String]


def main() raises:
    var config = ArcPointer(String("region=us-west"))

    var kept = Replicas(config.copy(), config.copy())
    assert_equal(config.count(), 3)
    _ = kept^  # Normal destruction: both fields release their share.
    assert_equal(config.count(), 1)

    var dropped = Replicas(config.copy(), config.copy())
    forget_deinit(dropped^)
    assert_equal(config.count(), 3)  # Neither field released its share.
