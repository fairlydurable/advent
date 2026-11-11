# Claims:
# - Putting the field back in an `except` block before re-raising satisfies
#   the initialization rule on the error path.
# - The caller then sees the original contents after the failure.
from std.testing import assert_equal


def validate(reading: Int) raises:
    if reading < 0:
        raise Error("negative reading")


struct Inventory(Movable):
    var items: List[String]

    def __init__(out self):
        self.items = ["bolts"]

    def restock(mut self, reading: Int) raises:
        var taken = self.items^
        try:
            validate(reading)
        except e:
            self.items = taken^
            raise e^
        taken.append("washers")
        self.items = taken^


def main() raises:
    var stock = Inventory()
    try:
        stock.restock(-1)
    except e:
        assert_equal(String(e), "negative reading")
    assert_equal(stock.items, ["bolts"])
    stock.restock(3)
    assert_equal(stock.items, ["bolts", "washers"])
