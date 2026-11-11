# EXPECT-ERROR: a `mut self` method called on a temporary
# EXPECT-MATCH: invalid use of mutating method on rvalue
# Claim: `mut self` needs a place to write back to. A temporary has none, so
# the call fails to compile instead of mutating a value that vanishes.
@fieldwise_init
struct RetryBudget(Movable):
    var remaining: Int

    def spend(mut self):
        self.remaining -= 1


def main():
    RetryBudget(3).spend()
