# Claims (3.1):
# - A Pointer declared with a union origin can point at any member of the union.
# - The union origin is mutable when every member is mutable, so writes work.
from std.testing import assert_equal


def main() raises:
    var primary = String("lane-a")
    var spare = String("lane-b")
    var cursor: Pointer[String, origin_of(primary, spare)] = Pointer(to=primary)
    assert_equal(cursor[], "lane-a")

    cursor = Pointer(to=spare)
    cursor[] += "!"
    assert_equal(spare, "lane-b!")
    assert_equal(primary, "lane-a")
