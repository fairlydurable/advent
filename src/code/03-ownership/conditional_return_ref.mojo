# Claim (3.4): a function may mutate its argument on one path and return a
# reference into it on every path. The checker accepts this shape.
from std.testing import assert_equal


def slot(mut counts: List[Int], index: Int) -> ref[counts[0]] Int:
    if index >= len(counts):
        counts.append(0)
        return counts[len(counts) - 1]
    return counts[index]


def main() raises:
    var counts: List[Int] = [5]
    slot(counts, 0) += 1
    slot(counts, 7) += 1
    assert_equal(counts, [6, 1])
