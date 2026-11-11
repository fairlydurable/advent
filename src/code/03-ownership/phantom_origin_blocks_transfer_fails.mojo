# EXPECT-ERROR: the arena moves away while a ticket bound to its origin is still used
# EXPECT-MATCH: use of uninitialized value 'arena'
# Claim (3.10): an origin parameter alone is enough for the checker to treat
# the ticket as a borrow of the arena.


struct Ticket[o: ImmOrigin](ImplicitlyCopyable):
    var slot: Int

    def __init__(out self, ref[Self.o] arena: List[Int], slot: Int):
        self.slot = slot


def redeem(ticket: Ticket) -> Int:
    return ticket.slot


def main():
    var arena: List[Int] = [10, 20]
    var ticket = Ticket(arena, 1)
    var moved = arena^
    print(redeem(ticket), len(moved))
