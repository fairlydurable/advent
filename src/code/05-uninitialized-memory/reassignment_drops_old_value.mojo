# Claim: with ASAP destruction, the old value of a reassigned binding dies at
# its last read, before the assignment. Evaluating the argument
# "loaded " + config.label is that last read, so "drop v1" lands in the log
# before "loaded v1" does.
# Claim: the new value then lives until its own last use.
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def main() raises:
    var events = List[String]()
    var config = Tracer("v1", events)
    events.append("loaded " + config.label)
    config = Tracer("v2", events)
    events.append("loaded " + config.label)
    _ = config^
    assert_equal(events, ["drop v1", "loaded v1", "loaded v2", "drop v2"])
