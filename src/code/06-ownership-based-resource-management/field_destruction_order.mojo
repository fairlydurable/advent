# Claims:
# - Fields of a struct with no custom `__deinit__` die in declaration order,
#   regardless of the order `__init__` initialized them.
# - Inside a custom `__deinit__`, fields are ordinary owned values: each one
#   dies after its own last use in the body. A field the body never touches
#   dies before the body's first statement. A field read inside an
#   expression dies as soon as that read finishes, even mid-statement.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Part(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(out self, name: String, journal: ArcPointer[List[String]]):
        self.name = name
        self.journal = journal

    def __deinit__(deinit self):
        self.journal[].append("drop " + self.name)


struct Engine(Movable):
    var crankshaft: Part
    var piston: Part

    def __init__(out self, journal: ArcPointer[List[String]]):
        self.piston = Part("piston", journal)
        self.crankshaft = Part("crankshaft", journal)


struct Gearbox(Movable):
    var housing: Part
    var clutch: Part
    var journal: ArcPointer[List[String]]

    def __init__(out self, journal: ArcPointer[List[String]]):
        self.housing = Part("housing", journal)
        self.clutch = Part("clutch", journal)
        self.journal = journal

    def __deinit__(deinit self):
        self.journal[].append("gearbox body starts")
        self.journal[].append("inspect " + self.clutch.name)
        self.journal[].append("gearbox body ends")


def main() raises:
    var journal = ArcPointer(List[String]())
    _ = Engine(journal)
    assert_equal(journal[], ["drop crankshaft", "drop piston"])

    journal[].clear()
    _ = Gearbox(journal)
    assert_equal(
        journal[],
        [
            "drop housing",
            "gearbox body starts",
            "drop clutch",
            "inspect clutch",
            "gearbox body ends",
        ],
    )
