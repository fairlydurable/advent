# Claim: if a function raises after initializing its `out` argument, Mojo
# destroys that value before the error reaches the caller.
# Claim: if an __init__ raises after setting some fields, Mojo destroys
# exactly the fields that were set, and never runs __deinit__.
from std.testing import assert_equal


struct Tracer[origin: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.origin]

    def __init__(out self, label: String, ref[Self.origin] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def open_session[
    origin: MutOrigin
](ref[origin] log: List[String], fail: Bool, out session: Tracer[origin]) raises:
    session = Tracer("session", log)
    if fail:
        raise Error("handshake refused")


struct Pipeline[origin: MutOrigin](Movable):
    var reader: Tracer[Self.origin]
    var writer: Tracer[Self.origin]

    def __init__(out self, ref[Self.origin] log: List[String]) raises:
        self.reader = Tracer("reader", log)
        raise Error("writer unavailable")

    def __deinit__(deinit self):
        self.reader.log[].append("Pipeline.__deinit__")


def main() raises:
    var events = List[String]()
    try:
        _ = open_session(events, True)
    except e:
        events.append(String(e))
    try:
        _ = Pipeline(events)
    except e:
        events.append(String(e))
    assert_equal(
        events,
        ["drop session", "handshake refused", "drop reader", "writer unavailable"],
    )
