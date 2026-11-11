# Claim: when one branch transfers a value away, Mojo destroys it on the other
# branch at that branch's entry, because the condition was its last use there.
# No run-time flag records whether the value moved.
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


def archive(var tracer: Tracer):
    var label = tracer.label
    tracer^.log[].append("archive " + label)


def main() raises:
    var events = List[String]()
    var offline = len(argv()) == 0  # false at run time
    var snapshot = Tracer("snapshot", events)
    if offline:
        archive(snapshot^)
    else:
        events.append("else entered")
        events.append("else finished")
    events.append("joined")
    assert_equal(
        events, ["drop snapshot", "else entered", "else finished", "joined"]
    )
