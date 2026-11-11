# Claim: you can transfer one field out of a local struct value, as long as
# you put a new value back before anything uses or destroys the whole.
# Claim: the transferred-out value dies at its new owner's last use. Inside
# `retire`, that last use is evaluating the append's arguments, so "drop eth0"
# lands in the log before "retire eth0" does.
# Claim: the replacement field dies with the struct.
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


def retire(var tracer: Tracer):
    tracer.log[].append("retire " + tracer.label)


def main() raises:
    var events = List[String]()
    var link = Link(events, "eth0", "wlan0")
    retire(link.primary^)
    link.primary = Tracer("eth1", events)
    events.append("relinked " + link.primary.label)
    _ = link^
    assert_equal(
        events,
        ["drop eth0", "retire eth0", "relinked eth1", "drop eth1", "drop wlan0"],
    )
