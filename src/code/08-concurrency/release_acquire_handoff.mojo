# Claims:
#   - A RELEASE store to a flag publishes every write the thread made
#     before it. An ACQUIRE load that sees the flag sees all of them.
#   - With that pairing, the payload itself needs no atomics: the consumer
#     reads plain fields and always finds the producer's values.
from threads import ThreadArg, erase, spawn, join
from std.atomic import Atomic, Ordering
from std.testing import assert_equal


struct Mailbox(Movable):
    var ready: Atomic[UInt8]
    var sequence: Int
    var payload_bytes: Int
    var observed_sequence: Int
    var observed_bytes: Int

    def __init__(out self):
        self.ready = Atomic[UInt8](0)
        self.sequence = 0
        self.payload_bytes = 0
        self.observed_sequence = 0
        self.observed_bytes = 0


def produce(arg: ThreadArg) abi("C") -> ThreadArg:
    var mailbox = arg.unsafe_bitcast[Mailbox]()
    mailbox[].sequence = 1729          # plain writes...
    mailbox[].payload_bytes = 65536
    mailbox[].ready.store[ordering=Ordering.RELEASE](1)  # ...published here
    return arg


def consume(arg: ThreadArg) abi("C") -> ThreadArg:
    var mailbox = arg.unsafe_bitcast[Mailbox]()
    while mailbox[].ready.load[ordering=Ordering.ACQUIRE]() == 0:
        pass
    mailbox[].observed_sequence = mailbox[].sequence  # plain reads, now safe
    mailbox[].observed_bytes = mailbox[].payload_bytes
    return arg


def main() raises:
    var mailbox = Mailbox()
    var consumer = spawn(consume, erase(mailbox))
    var producer = spawn(produce, erase(mailbox))
    join(producer)
    join(consumer)
    assert_equal(mailbox.observed_sequence, 1729)
    assert_equal(mailbox.observed_bytes, 65536)
