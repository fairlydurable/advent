# Claims (3.3):
# - `origin_of()` accepts a value path such as `depot.north`, and names the
#   origin of that field only.
# - A pointer typed with a field origin accepts only a pointer to that field.
from std.testing import assert_equal


@fieldwise_init
struct Depot(Movable):
    var north: Int
    var south: Int


def main() raises:
    var depot = Depot(north=40, south=12)
    var bay: Pointer[Int, origin_of(depot.north)] = Pointer(to=depot.north)
    bay[] += 2
    depot.south += 1
    assert_equal(bay[], 42)
    assert_equal(depot.south, 13)
