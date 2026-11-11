# Claim (3.11): two `ref` bindings to different elements of one List can both
# write. Exclusivity applies to the arguments of a call, not to local bindings.
from std.testing import assert_equal


def main() raises:
    var cells: List[Int] = [1, 2, 3, 4]
    ref first = cells[0]
    ref last = cells[3]
    first += 10
    last += 20
    assert_equal(cells, [11, 2, 3, 24])
