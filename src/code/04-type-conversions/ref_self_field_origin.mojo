# Claim: a `ref self` method returns a reference whose mutability follows the
# caller: assignable through a mutable binding, read-only through a `read`
# argument.
# Claim: the return origin names the list element, so the reference stays
# tied to the readings storage, not to all of self.
# Claim: a `deinit self` method can move a field out and end the value.
from std.testing import assert_equal


struct Recorder(Movable):
    var name: String
    var readings: List[Int]

    def __init__(out self, name: String):
        self.name = name
        self.readings = []

    def latest(ref self) -> ref[self.readings[0]] Int:
        return self.readings[len(self.readings) - 1]

    def finish(deinit self) -> List[Int]:
        return self.readings^


def peek(recorder: Recorder) -> Int:
    return recorder.latest()


def main() raises:
    var recorder = Recorder("inlet")
    recorder.readings.append(5500)
    recorder.latest() += 25  # mutable binding, so the reference is mutable
    assert_equal(peek(recorder), 5525)
    var samples = recorder^.finish()
    assert_equal(len(samples), 1)
