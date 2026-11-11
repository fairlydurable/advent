# Claim: inside __deinit__, each field dies at its own last use, not after the
# body. A field the body never touches dies before the body runs.
# Claim: a value nobody uses dies right after construction.
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


struct Rig[origin: MutOrigin](Movable):
    var motor: Tracer[Self.origin]
    var sensor: Tracer[Self.origin]
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, ref[Self.origin] log: List[String]):
        self.motor = Tracer("motor", log)
        self.sensor = Tracer("sensor", log)
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("body start")
        self.log[].append("reading " + self.sensor.label)
        self.log[].append("body end")


def main() raises:
    var events = List[String]()
    _ = Rig(events)
    events.append("after rig")
    assert_equal(
        events,
        [
            "drop motor",
            "body start",
            "drop sensor",
            "reading sensor",
            "body end",
            "after rig",
        ],
    )
