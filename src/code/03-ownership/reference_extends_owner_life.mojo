# Claims (3.1, 3.9):
# - A value without later uses dies immediately (ASAP destruction).
# - A live Pointer keeps its owner alive until the pointer's last use.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


def main() raises:
    var log = List[String]()
    var sensor = Probe("sensor", log)
    var cursor = Pointer(to=sensor)
    log.append("pointer made")
    _ = Probe("unused", log)
    log.append("read " + cursor[].label)
    log.append("end")
    assert_equal(
        log,
        [
            "pointer made",
            "deinit unused",
            "deinit sensor",
            "read sensor",
            "end",
        ],
    )
