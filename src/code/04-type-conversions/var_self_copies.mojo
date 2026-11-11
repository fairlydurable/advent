# Claim: for an ImplicitlyCopyable type, a `var self` method receives a copy,
# and the caller's value stays unchanged.
from std.testing import assert_equal


@fieldwise_init
struct RetryBudget(ImplicitlyCopyable):
    var remaining: Int

    def drain(var self) -> Int:
        self.remaining = 0
        return self.remaining


def main() raises:
    var budget = RetryBudget(3)
    assert_equal(budget.drain(), 0)
    assert_equal(budget.remaining, 3)
