# Claim (3.9): consuming a linear value through its `deinit` method satisfies
# the checker.
from std.testing import assert_equal


struct Receipt(not Deinitable, Movable):
    var amount: Int

    def __init__(out self, amount: Int):
        self.amount = amount

    def file(deinit self) -> Int:
        return self.amount


def main() raises:
    var receipt = Receipt(120)
    assert_equal(receipt^.file(), 120)
