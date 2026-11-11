# Claims:
# - A List can hold linear elements; inserting needs only Movable.
# - Such a List is itself linear: end it with `deinit_with`, which hands
#   each element to your function by value.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self) -> Int:
        return self.id


def main() raises:
    var resolved = ArcPointer(List[Int]())
    var backlog = List[Ticket]()
    backlog.append(Ticket(301))
    backlog.append(Ticket(302))
    backlog.append(Ticket(303))

    def close_ticket(var ticket: Ticket) {var resolved}:
        resolved[].append(ticket^.resolve())

    backlog^.deinit_with(close_ticket)
    assert_equal(resolved[], [301, 302, 303])
