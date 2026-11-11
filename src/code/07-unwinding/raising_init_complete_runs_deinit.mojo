# Claims:
# - Once `__init__` has initialized every field and has no field writes
#   left, `self` is a complete value. If `__init__` raises after that
#   point, Mojo destroys `self` as a whole, which runs the struct's
#   `__deinit__`.
# - So a `__deinit__` can run on a value whose `__init__` never finished;
#   it must not assume that post-initialization work happened.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Worker(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(
        out self, name: String, journal: ArcPointer[List[String]]
    ) raises:
        self.name = name
        self.journal = journal
        if name == "":
            raise Error("worker needs a name")
        journal[].append("register " + name)

    def __deinit__(deinit self):
        self.journal[].append("Worker.__deinit__")


def main() raises:
    var journal = ArcPointer(List[String]())
    try:
        _ = Worker("", journal)
    except e:
        journal[].append(String(e))
    assert_equal(journal[], ["Worker.__deinit__", "worker needs a name"])
