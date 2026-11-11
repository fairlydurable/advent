# Claim: Mojo destroys a value right after its last use, not at the end of
# the enclosing scope.
# Claim: `deinit(value^)` extends a value's lifetime to that exact point.
from std.testing import assert_equal


struct Valve[origin: MutOrigin]:
    var name: String
    var events: Pointer[List[String], Self.origin]

    def __init__(out self, name: String, ref[Self.origin] events: List[String]):
        self.name = name
        self.events = Pointer(to=events)
        self.events[].append("open " + name)

    def __deinit__(deinit self):
        self.events[].append("close " + self.name)


def main() raises:
    var events = List[String]()

    var intake = Valve("intake", events)
    var exhaust = Valve("exhaust", events)
    # `intake` has no use after its construction, so it closed before
    # `exhaust` opened.
    assert_equal(events[1], "close intake")
    assert_equal(events[2], "open exhaust")

    events.append("checkpoint")
    deinit(exhaust^)  # Keeps `exhaust` alive until this line.
    assert_equal(events[3], "checkpoint")
    assert_equal(events[4], "close exhaust")
    print("events:", len(events))  # events: 5
