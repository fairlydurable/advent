# Claims (3.6, 3.9):
# - A pointer cast to `MutUntrackedOrigin` no longer counts as a use of its
#   owner, so the owner dies at its last tracked use.
# - Converting a pointer to `Int` and passing a pointer to a function both
#   count as uses; the owner dies right after that use, before the enclosing
#   statement finishes.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


def still_held(cursor: Pointer) -> Bool:
    return True


def main() raises:
    var log = List[String]()
    var by_address = Probe("by_address", log)
    var by_call = Probe("by_call", log)
    var untracked = Probe("untracked", log)
    var address_cursor = Pointer(to=by_address)
    var call_cursor = Pointer(to=by_call)
    var raw_cursor = Pointer(to=untracked).unsafe_origin_cast[
        MutUntrackedOrigin
    ]()
    log.append("pointers made")
    _ = Int(address_cursor)
    log.append("after address")
    _ = still_held(call_cursor)
    log.append("after call")
    _ = still_held(raw_cursor)
    log.append("end")
    assert_equal(
        log,
        [
            "deinit untracked",
            "pointers made",
            "deinit by_address",
            "after address",
            "deinit by_call",
            "after call",
            "end",
        ],
    )
