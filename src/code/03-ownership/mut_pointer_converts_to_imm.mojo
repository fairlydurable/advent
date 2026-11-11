# Claims (3.8):
# - A mutable `Pointer` or `Span` converts implicitly to its immutable form
#   wherever a function asks for an immutable origin.
from std.testing import assert_equal


def byte_count[o: ImmOrigin](cursor: Pointer[String, o]) -> Int:
    return cursor[].byte_length()


def total[o: ImmOrigin](readings: Span[Int, o]) -> Int:
    var sum = 0
    for reading in readings:
        sum += reading
    return sum


def main() raises:
    var city = String("Quito")
    assert_equal(byte_count(Pointer(to=city)), 5)
    var counts: List[Int] = [4, 5]
    assert_equal(total(Span(counts)), 9)
