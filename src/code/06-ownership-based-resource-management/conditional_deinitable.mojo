# Claims:
# - `Deinitable where <condition>` makes a generic struct implicitly
#   destructible only for element types that are.
# - The same struct then works with linear elements, provided the caller
#   ends it through a named `deinit` method.
# - A generic field of type `T` needs this: without `T: Deinitable` or a
#   conditional conformance, the field is rejected.
from std.testing import assert_equal


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self) -> Int:
        return self.id


struct Envelope[T: Movable](
    Movable,
    Deinitable where conforms_to(T, Deinitable) else (
        "an Envelope of linear contents must be opened with open()"
    ),
):
    var contents: Self.T

    def __init__(out self, var contents: Self.T):
        self.contents = contents^

    def open(deinit self) -> Self.T:
        return self.contents^


def main() raises:
    var letter = Envelope[String]("invoice #2231")
    assert_equal(letter.contents, "invoice #2231")

    var sealed = Envelope[Ticket](Ticket(88))
    var ticket = sealed^.open()
    assert_equal(ticket^.resolve(), 88)
