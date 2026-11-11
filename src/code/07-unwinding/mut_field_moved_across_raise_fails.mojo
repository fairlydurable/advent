# EXPECT-ERROR: a raise could leave a field of a mut argument moved out
# EXPECT-MATCH: use of uninitialized value 'self\.items'
# Claim: a `mut` argument must be fully initialized on every exit, and the
# error path counts as an exit. Moving a field out across a call that can
# raise is a compile error.


def validate(reading: Int) raises:
    if reading < 0:
        raise Error("negative reading")


struct Inventory(Movable):
    var items: List[String]

    def __init__(out self):
        self.items = ["bolts"]

    def restock(mut self, reading: Int) raises:
        var taken = self.items^
        validate(reading)
        taken.append("washers")
        self.items = taken^


def main() raises:
    var stock = Inventory()
    stock.restock(3)
