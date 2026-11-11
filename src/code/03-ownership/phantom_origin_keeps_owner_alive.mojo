# Claim (3.10): a struct that only carries an origin parameter, with no pointer
# field, still keeps that origin's owner alive while the struct lives.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


struct Ticket[o: ImmOrigin](ImplicitlyCopyable):
    var slot: Int

    def __init__[
        log_origin: MutOrigin
    ](out self, ref[Self.o] arena: Probe[log_origin], slot: Int):
        self.slot = slot


def redeem(ticket: Ticket) -> Int:
    return ticket.slot


def main() raises:
    var log = List[String]()
    var arena = Probe("arena", log)
    var ticket = Ticket(arena, 3)
    log.append("ticket issued")
    var slot = redeem(ticket)
    log.append("redeemed")
    assert_equal(slot, 3)
    assert_equal(log, ["ticket issued", "deinit arena", "redeemed"])
