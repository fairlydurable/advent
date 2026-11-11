# Claims (3.9):
# - Reassignment does not keep the old value alive until the `=`. The old
#   value dies after its own last use, here right after construction.
# - The new value dies right after the expression that last reads it, before
#   the enclosing call (`log.append`) runs.
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
    var shift = Probe("morning", log)
    log.append("reassigning")
    shift = Probe("evening", log)
    log.append("reassigned " + shift.label)
    assert_equal(
        log,
        ["deinit morning", "reassigning", "deinit evening", "reassigned evening"],
    )
