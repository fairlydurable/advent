# Claim (3.4): writing one element through subscript is not a `mut self` call
# that can reallocate, so a reference to another element stays valid.
from std.testing import assert_equal


def main() raises:
    var names: List[String] = ["ada", "grace"]
    ref first = names[0]
    names[1] = "linus"
    first += "!"
    assert_equal(names, ["ada!", "linus"])
