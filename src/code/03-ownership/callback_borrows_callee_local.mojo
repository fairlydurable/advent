# Claim (3.7): a callback can receive a reference to a value that lives only
# inside the callee. The caller never names that value's origin, and the
# reference cannot outlive the call.
from std.testing import assert_equal


def with_scratch(work: Some[def(mut List[Int]) -> Int]) -> Int:
    var scratch = List[Int](capacity=8)
    return work(scratch)


def main() raises:
    def fill_and_sum(mut scratch: List[Int]) -> Int:
        for reading in [12, 30, 8]:
            scratch.append(reading)
        var total = 0
        for reading in scratch:
            total += reading
        return total

    assert_equal(with_scratch(fill_and_sum), 50)
