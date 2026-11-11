# Claim: an `imm` argument of a trivial register-passable type such as `Int`
# arrives as a copy, so passing one value to both a `mut` and an `imm`
# argument is legal and the `imm` side sees the value from the call site.
from std.testing import assert_equal


def add_interest(mut balance: Int, imm basis: Int):
    balance += basis // 10
    balance += basis // 10


def main() raises:
    var balance = 1000
    add_interest(balance, balance)
    assert_equal(balance, 1200)  # Both steps used the original 1000.
