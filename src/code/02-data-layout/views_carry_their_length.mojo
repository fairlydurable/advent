# Claim: Mojo has no dynamically sized types. Runtime-length data lives
# behind a view that stores a pointer and a length side by side (`Span`,
# `StringSpan`), or puts the length in the type (`Array[T, N]`).
# Claim: a `List` stores its pointer, capacity, and length inline.
from std.sys import size_of
from std.testing import assert_equal


def total(readings: Span[Int, _]) -> Int:
    var sum = 0
    for reading in readings:
        sum += reading
    return sum


def main() raises:
    assert_equal(size_of[Span[Int, MutUntrackedOrigin]](), 16)
    assert_equal(size_of[StringSpan[ImmStaticOrigin]](), 16)
    assert_equal(size_of[List[Int]](), 24)
    assert_equal(size_of[Array[Int, 3]](), 24)

    var hourly: List[Int] = [12, 15, 19, 22]
    var fixed = Array[Int, 3](fill=7)
    assert_equal(total(Span(hourly)), 68)
    assert_equal(total(Span(fixed)), 21)
