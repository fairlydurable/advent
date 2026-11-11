# Claim (3.4): converting a tracked Pointer to `MutAnyOrigin` compiles in code
# with no `unsafe_` call, and the local it points at dies before the function
# returns. The caller receives a dangling address. This sample never
# dereferences it.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


def escape[o: MutOrigin](ref[o] log: List[String]) -> Pointer[Probe[o], MutAnyOrigin]:
    var local = Probe("local", log)
    var cursor = Pointer(to=local)
    log.append("returning")
    return cursor


def main() raises:
    var log = List[String]()
    var dangling = escape(log)
    log.append("caller holds address")
    _ = Int(dangling)
    assert_equal(log, ["deinit local", "returning", "caller holds address"])
