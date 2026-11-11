# Claim: the builtin deinit(value^) keeps a value alive up to that call, then
# destroys it there, overriding ASAP destruction.
# Claim: a live reference counts as a use, so the referent lives until the
# reference's last use.
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
    var lock = Tracer("lock", events)
    var token = Tracer("token", events)
    events.append("critical section")
    deinit(lock^)
    ref current = token
    events.append("between")
    var label = current.label  # last use of the reference, so token dies here
    assert_equal(
        events, ["critical section", "drop lock", "between", "drop token"]
    )
    assert_equal(label, "token")
