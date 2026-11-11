# Claims:
# - When `__init__` raises before every field is initialized, Mojo destroys
#   the fields already initialized, one by one, and does not run the
#   struct's `__deinit__`.
# - Fields not yet initialized are never touched.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Resource(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(out self, name: String, journal: ArcPointer[List[String]]):
        self.name = name
        self.journal = journal

    def __deinit__(deinit self):
        self.journal[].append("release " + self.name)


struct Connection(Movable):
    var socket: Resource
    var tls: Resource
    var journal: ArcPointer[List[String]]

    def __init__(
        out self, journal: ArcPointer[List[String]], handshake_ok: Bool
    ) raises:
        self.journal = journal
        self.socket = Resource("socket", journal)
        if not handshake_ok:
            raise Error("handshake failed")
        self.tls = Resource("tls session", journal)

    def __deinit__(deinit self):
        self.journal[].append("Connection.__deinit__")


def main() raises:
    var journal = ArcPointer(List[String]())
    try:
        _ = Connection(journal, handshake_ok=False)
    except e:
        journal[].append(String(e))
    assert_equal(journal[], ["release socket", "handshake failed"])
