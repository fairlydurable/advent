# Claims:
# - Mojo destroys a value after its last use, not at the end of the scope.
# - A value that is never used after construction dies right away.
# - "Last use" is finer than a statement: here `request` dies as soon as
#   `"handle " + request.name` finishes evaluating, before `append` runs.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Span(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(out self, name: String, journal: ArcPointer[List[String]]):
        self.name = name
        self.journal = journal
        self.journal[].append("open " + name)

    def __deinit__(deinit self):
        self.journal[].append("close " + self.name)


def main() raises:
    var journal = ArcPointer(List[String]())

    var request = Span("request", journal)
    journal[].append("handle " + request.name)
    journal[].append("respond")
    _ = Span("unused", journal)
    journal[].append("done")

    assert_equal(
        journal[],
        [
            "open request",
            "close request",
            "handle request",
            "respond",
            "open unused",
            "close unused",
            "done",
        ],
    )
