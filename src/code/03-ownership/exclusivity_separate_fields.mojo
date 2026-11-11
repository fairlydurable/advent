# Claim (3.2, 3.11): distinct fields of a struct have distinct origins, so one
# call may take both mutably.
from std.testing import assert_equal


@fieldwise_init
struct Bounds(Movable):
    var lower: String
    var upper: String


def main() raises:
    var bounds = Bounds("north", "south")
    swap(bounds.lower, bounds.upper)
    assert_equal(bounds.lower, "south")
    assert_equal(bounds.upper, "north")
