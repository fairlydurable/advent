# Claims:
# - Making one direction of the link weak breaks the ownership cycle.
# - When the last strong pointer dies, the destructor runs, and the weak
#   pointer can no longer upgrade.
from std.memory import ArcPointer
from std.memory.arc_pointer import WeakPointer
from std.testing import assert_equal, assert_false


struct Child(Movable):
    var name: String
    var parent: WeakPointer[Parent]

    def __init__(out self, name: String):
        self.name = name
        self.parent = WeakPointer[Parent]()


struct Parent(Movable):
    var name: String
    var children: List[ArcPointer[Child]]
    var closed: ArcPointer[Int]

    def __init__(out self, name: String, closed: ArcPointer[Int]):
        self.name = name
        self.children = List[ArcPointer[Child]]()
        self.closed = closed

    def __deinit__(deinit self):
        self.closed[] += 1


def build(closed: ArcPointer[Int]) -> WeakPointer[Parent]:
    var root = ArcPointer(Parent("cluster", closed))
    var leaf = ArcPointer(Child("node-7"))
    leaf[].parent = WeakPointer(downgrade=root)
    root[].children.append(leaf)
    return WeakPointer(downgrade=root)


def main() raises:
    var closed = ArcPointer(0)
    var probe = build(closed)
    assert_equal(closed[], 1)
    assert_false(Bool(probe.try_upgrade()))
