# Claims (3.8):
# - Two pointers with different origins merge into one pointer whose origin is
#   the union of both.
# - The merged pointer stays mutable when both inputs are mutable.
from std.testing import assert_equal


def main() raises:
    var north = String("north")
    var south = String("south")
    var heading_north = True
    var heading = Pointer(to=north) if heading_north else Pointer(to=south)
    heading[] += "!"
    assert_equal(north, "north!")
    assert_equal(south, "south")
