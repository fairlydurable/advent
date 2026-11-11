# EXPECT-ERROR: a struct with an implicit destructor cannot hold a linear field
# EXPECT-MATCH: field 'open_ticket' has non-'Deinitable' type
# Claim: linearity propagates. A struct that contains a `not Deinitable`
# field must itself be `not Deinitable` (or conditionally Deinitable).


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self):
        pass


struct HelpDesk:
    var open_ticket: Ticket

    def __init__(out self):
        self.open_ticket = Ticket(1)


def main():
    pass
