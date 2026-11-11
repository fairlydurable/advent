# Claims (3.9):
# - A struct whose `__deinit__` reads through a stored pointer runs that
#   deinitializer before its referent dies; the referent outlives the holder.
# - An unused holder dies right after construction.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


struct Inspector[log_origin: MutOrigin, o: ImmOrigin](Movable):
    var target: Pointer[Probe[Self.log_origin], Self.o]

    def __init__(out self, ref[Self.o] target: Probe[Self.log_origin]):
        self.target = Pointer(to=target)

    def __deinit__(deinit self):
        self.target[].log[].append("inspected " + self.target[].label)


def main() raises:
    var log = List[String]()
    var gauge = Probe("gauge", log)
    _ = Inspector(gauge)
    log.append("end")
    assert_equal(log, ["inspected gauge", "deinit gauge", "end"])
