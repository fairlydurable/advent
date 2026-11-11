# EXPECT-ERROR: a named destructor forgets to end a linear field
# EXPECT-MATCH: 'self' abandoned without being explicitly destroyed
# Claim: inside a `deinit self` method, every linear field still needs its
# own named destructor before the method returns.


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self):
        pass


struct HelpDesk(not Deinitable):
    var open_ticket: Ticket
    var clerk: String

    def __init__(out self):
        self.open_ticket = Ticket(1)
        self.clerk = "ana"

    def close_for_day(deinit self):
        print("closing", self.clerk)


def main():
    var desk = HelpDesk()
    desk^.close_for_day()
