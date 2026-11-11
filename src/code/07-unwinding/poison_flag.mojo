# Claims:
# - Mojo has no built-in lock poisoning; you build it from a flag.
# - Set the flag before running a mutation that can raise and clear it only
#   on success. A raise leaves the flag set, and every later access refuses
#   to proceed until someone repairs the value.
from std.testing import assert_equal, assert_raises, assert_true


struct Guarded[T: Movable & Deinitable](Movable):
    var value: Self.T
    var poisoned: Bool

    def __init__(out self, var value: Self.T):
        self.value = value^
        self.poisoned = False

    def update(mut self, mutation: Some[def(mut Self.T) raises -> None]) raises:
        if self.poisoned:
            raise Error("poisoned: an earlier update raised mid-mutation")
        self.poisoned = True
        mutation(self.value)
        self.poisoned = False

    def repair(mut self, var trusted: Self.T):
        self.value = trusted^
        self.poisoned = False


def deposit(mut accounts: List[Int]) raises:
    accounts[0] += 100


def overdrawn_transfer(mut accounts: List[Int]) raises:
    accounts[0] -= 900
    if accounts[0] < 0:
        raise Error("overdraft")
    accounts[1] += 900


def main() raises:
    var balances = Guarded[List[Int]]([500, 250])
    balances.update(deposit)
    assert_equal(balances.value, [600, 250])

    with assert_raises(contains="overdraft"):
        balances.update(overdrawn_transfer)
    assert_true(balances.poisoned)
    # The half-applied transfer is visible: this is the state poisoning
    # protects later callers from.
    assert_equal(balances.value, [-300, 250])

    with assert_raises(contains="poisoned"):
        balances.update(deposit)

    balances.repair([600, 250])
    balances.update(deposit)
    assert_equal(balances.value, [700, 250])
