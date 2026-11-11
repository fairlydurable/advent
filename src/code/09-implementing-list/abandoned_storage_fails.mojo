# EXPECT-ERROR: replacing an Allocation field without releasing the old one abandons it
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim: a growth routine that overwrites its storage field without
# deallocating the old block does not compile. The leak is a type error.

from std.memory import Allocation, Layout, alloc, dealloc


struct Readings(Movable):
    var _storage: Allocation[Float64]

    def __init__(out self):
        self._storage = alloc(Layout[Float64](length=4))

    def grow(mut self):
        var old = self._storage^
        self._storage = alloc(Layout[Float64](length=len(old) * 2))
        # forgot: dealloc(old^)

    def __deinit__(deinit self):
        dealloc(self._storage^)


def main():
    var readings = Readings()
    readings.grow()
