# EXPECT-ERROR: a linear value reaches the end of its life without a named destructor
# EXPECT-MATCH: abandoned without being explicitly destroyed: close the ticket with resolve
# Claim: `not Deinitable else "..."` makes abandoning a value a compile
# error, and the compiler appends your message to the diagnostic.


struct Ticket(not Deinitable else "close the ticket with resolve() or escalate()"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self):
        pass

    def escalate(deinit self) -> Int:
        return self.id


def main():
    var ticket = Ticket(4417)
    print(ticket.id)
