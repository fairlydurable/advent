# Claims:
# - A linear (`not Deinitable`) value is legal once every path ends it
#   through a named `deinit` method.
# - Different branches may pick different named destructors.
from std.testing import assert_equal


struct Ticket(not Deinitable else "close the ticket with resolve() or escalate()"):
    var id: Int
    var severity: Int

    def __init__(out self, id: Int, severity: Int):
        self.id = id
        self.severity = severity

    def resolve(deinit self) -> Int:
        return 0

    def escalate(deinit self) -> Int:
        return self.id


def triage(var ticket: Ticket) -> Int:
    if ticket.severity >= 3:
        return ticket^.escalate()
    return ticket^.resolve()


def main() raises:
    assert_equal(triage(Ticket(4417, severity=4)), 4417)
    assert_equal(triage(Ticket(4418, severity=1)), 0)
