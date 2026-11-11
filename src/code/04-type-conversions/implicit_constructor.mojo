# Claim: an @implicit constructor lets the compiler convert a value at an
# argument, an annotated `var`, or a `return`.
# Claim: the conversion is one hop. An explicit Seconds converts to Millis,
# and an integer literal converts to Seconds.
from std.testing import assert_equal


struct Seconds(ImplicitlyCopyable):
    var count: Int

    @implicit
    def __init__(out self, count: Int):
        self.count = count


struct Millis(ImplicitlyCopyable):
    var count: Int

    @implicit
    def __init__(out self, seconds: Seconds):
        self.count = seconds.count * 1000


def timeout_budget(duration: Millis) -> Int:
    return duration.count


def default_backoff() -> Seconds:
    return 30  # converts through Seconds.__init__(count:)


def main() raises:
    assert_equal(timeout_budget(Seconds(3)), 3000)
    var grace: Seconds = 45
    assert_equal(grace.count, 45)
    assert_equal(default_backoff().count, 30)
