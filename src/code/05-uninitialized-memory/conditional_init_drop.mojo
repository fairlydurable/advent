# Claim: a binding initialized on only one path, and never read afterward,
# dies on that path right after its initialization. The merge point never
# has to ask whether it holds a value.
from std.sys import argv
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
    var warm_start = len(argv()) > 0  # true at run time
    var cache: Tracer[origin_of(events)]
    if warm_start:
        cache = Tracer("cache", events)
        events.append("cache branch")
    events.append("joined")
    assert_equal(events, ["drop cache", "cache branch", "joined"])
