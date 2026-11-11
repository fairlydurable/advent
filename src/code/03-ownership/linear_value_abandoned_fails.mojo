# EXPECT-ERROR: a value of a non-Deinitable type reaches the end of its life unconsumed
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim (3.9): a `not Deinitable` type has no implicit destruction; every path
# must end in a `deinit` method or a transfer.


struct Receipt(not Deinitable, Movable):
    var amount: Int

    def __init__(out self, amount: Int):
        self.amount = amount

    def file(deinit self) -> Int:
        return self.amount


def main():
    var receipt = Receipt(120)
    print(receipt.amount)
