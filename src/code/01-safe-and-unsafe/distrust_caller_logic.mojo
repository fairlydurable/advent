# Claim: unsafe code may trust the types of the safe code it calls, but not
# its logic. This binary search reads through an unchecked pointer, so it
# keeps every probe inside [0, count) no matter what `precedes` answers.
# Claim: with an inconsistent comparison, the result is wrong but in bounds,
# which is a logic bug, not undefined behavior.
from std.testing import assert_equal, assert_true


def insertion_point(
    sorted_ms: Span[Int, _], target: Int, precedes: Some[def(Int, Int) -> Bool]
) -> Int:
    var data = sorted_ms.unsafe_ptr()
    var low = 0
    var high = len(sorted_ms)
    while low < high:
        var middle = low + (high - low) // 2  # low <= middle < high
        if precedes(data[unsafe_offset=middle], target):
            low = middle + 1
        else:
            high = middle
    return low


def by_value(lhs: Int, rhs: Int) -> Bool:
    return lhs < rhs


def always_yes(lhs: Int, rhs: Int) -> Bool:
    return True


def main() raises:
    var latencies_ms: List[Int] = [4, 9, 15, 22, 40]
    assert_equal(insertion_point(Span(latencies_ms), 16, by_value), 3)

    var position = insertion_point(Span(latencies_ms), 16, always_yes)
    assert_true(position >= 0 and position <= len(latencies_ms))
