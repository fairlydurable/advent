# Claim: a method that takes `deinit self` may transfer fields out freely; it
# replaces the type's __deinit__ for that value, so __deinit__ never runs.
# Claim: fields the method never touches die at the start of the method,
# because their last use has already passed (ASAP destruction).
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


struct Link[origin: MutOrigin](Movable):
    var primary: Tracer[Self.origin]
    var backup: Tracer[Self.origin]

    def __init__(
        out self, ref[Self.origin] log: List[String], primary: String, backup: String
    ):
        self.primary = Tracer(primary, log)
        self.backup = Tracer(backup, log)

    def __deinit__(deinit self):
        self.primary.log[].append("Link.__deinit__")

    def detach_primary(deinit self) -> Tracer[Self.origin]:
        self.primary.log[].append("detach")
        return self.primary^


def main() raises:
    var events = List[String]()
    var link = Link(events, "eth0", "wlan0")
    var kept = link^.detach_primary()
    events.append("kept " + kept.label)
    _ = kept^
    assert_equal(events, ["drop wlan0", "detach", "kept eth0", "drop eth0"])
