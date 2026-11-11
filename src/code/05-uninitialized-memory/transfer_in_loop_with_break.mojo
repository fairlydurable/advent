# Claim: a loop body may transfer a value away if that path leaves the loop,
# because no later iteration can reach the empty binding.
# Claim: on the path where the loop ends normally, the value dies after the
# loop, at the end of its last possible use.
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def ship(var tracer: Tracer):
    pass


def main() raises:
    var events = List[String]()
    var batch = Tracer("batch", events)
    var attempts = 0
    for attempt in range(3):
        attempts += 1
        if attempt == 7:  # never true in this run
            ship(batch^)
            break
    events.append("tried " + String(attempts))
    assert_equal(events, ["drop batch", "tried 3"])
