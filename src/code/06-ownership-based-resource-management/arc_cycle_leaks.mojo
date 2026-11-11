# Claims:
# - Two ArcPointers that point at each other keep each other alive: neither
#   strong count reaches zero, so neither destructor runs.
# - The leak is safe: the values stay valid and reachable through a weak
#   pointer, which can still upgrade after every local strong pointer dies.
from std.memory import ArcPointer
from std.memory.arc_pointer import WeakPointer
from std.testing import assert_equal, assert_true


struct Peer(Movable):
    var host: String
    var link: Optional[ArcPointer[Peer]]
    var closed: ArcPointer[Int]

    def __init__(out self, host: String, closed: ArcPointer[Int]):
        self.host = host
        self.link = None
        self.closed = closed

    def __deinit__(deinit self):
        self.closed[] += 1


def make_cycle(closed: ArcPointer[Int]) -> WeakPointer[Peer]:
    var east = ArcPointer(Peer("east.internal", closed))
    var west = ArcPointer(Peer("west.internal", closed))
    east[].link = west
    west[].link = east
    return WeakPointer(downgrade=east)


def main() raises:
    var closed = ArcPointer(0)
    var probe = make_cycle(closed)
    assert_equal(closed[], 0)

    var revived = probe.try_upgrade()
    assert_true(Bool(revived))
    assert_equal(revived.value()[].host, "east.internal")
    assert_equal(revived.value()[].link.value()[].host, "west.internal")
