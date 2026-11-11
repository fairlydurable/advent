# Claims:
# - The compiler checks initialization on error paths, not your invariants.
#   A raise between two related writes leaves both fields initialized and
#   the value inconsistent.
# - Ordering the work as "everything that can raise, then infallible
#   commits" keeps the invariant on every path.
from std.testing import assert_equal, assert_raises


def fee_for(amount: Int) raises -> Int:
    if amount > 10_000:
        raise Error("amount exceeds daily limit")
    return amount // 100


struct Ledger(Movable):
    var checking: Int
    var savings: Int

    def __init__(out self, checking: Int, savings: Int):
        self.checking = checking
        self.savings = savings

    def total(self) -> Int:
        return self.checking + self.savings

    def transfer_unsafe_order(mut self, amount: Int) raises:
        self.checking -= amount
        var fee = fee_for(amount)
        self.savings += amount - fee

    def transfer(mut self, amount: Int) raises:
        var fee = fee_for(amount)
        self.checking -= amount
        self.savings += amount - fee


def main() raises:
    var careless = Ledger(checking=50_000, savings=0)
    with assert_raises(contains="daily limit"):
        careless.transfer_unsafe_order(20_000)
    assert_equal(careless.total(), 30_000)

    var careful = Ledger(checking=50_000, savings=0)
    with assert_raises(contains="daily limit"):
        careful.transfer(20_000)
    assert_equal(careful.total(), 50_000)
