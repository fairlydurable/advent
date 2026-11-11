# Claims:
# - `raises ParseError` declares a typed error; the `except` binding has
#   that type, with its fields.
# - Raising is an ordinary return along a second path: every value still
#   live in the raising function is destroyed before the caller's `except`
#   block runs, and `finally` runs after it.
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct ParseError(Movable, Writable):
    var line: Int


struct Buffer(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(out self, name: String, journal: ArcPointer[List[String]]):
        self.name = name
        self.journal = journal

    def __deinit__(deinit self):
        self.journal[].append("free " + self.name)


def parse_line(
    line: Int, journal: ArcPointer[List[String]]
) raises ParseError -> Int:
    var scratch = Buffer("scratch", journal)
    if line > 2:
        raise ParseError(line)
    journal[].append("parsed with " + scratch.name)
    return line * 10


def main() raises:
    var journal = ArcPointer(List[String]())
    try:
        _ = parse_line(7, journal)
    except err:
        journal[].append(String("except line ", err.line))
    finally:
        journal[].append("finally")

    assert_equal(journal[], ["free scratch", "except line 7", "finally"])
