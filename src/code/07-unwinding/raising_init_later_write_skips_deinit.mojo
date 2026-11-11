# Claims:
# - Whether a raising `__init__` runs `__deinit__` depends on the code after
#   the raise point. Here every field holds a value when the raise happens,
#   but `__init__` writes `status` again afterward, so Mojo treats `self` as
#   incomplete: it destroys the initialized fields one by one and skips
#   `__deinit__`.
# - Design rule that follows: keep required cleanup in field types, and do
#   fallible work before initializing fields that own resources.
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


struct Worker(Movable):
    var socket: Resource
    var status: String
    var journal: ArcPointer[List[String]]

    def __init__(
        out self, name: String, journal: ArcPointer[List[String]]
    ) raises:
        self.journal = journal
        self.socket = Resource("socket", journal)
        self.status = "starting"
        if name == "":
            raise Error("worker needs a name")
        self.status = "ready"

    def __deinit__(deinit self):
        self.journal[].append("Worker.__deinit__")


def main() raises:
    var journal = ArcPointer(List[String]())
    try:
        _ = Worker("", journal)
    except e:
        journal[].append(String(e))
    assert_equal(journal[], ["release socket", "worker needs a name"])
