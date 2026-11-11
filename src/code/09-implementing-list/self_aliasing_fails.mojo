# EXPECT-ERROR: a pointer derived from all of mutable self aliases self._len, so passing both into one call violates exclusivity
# EXPECT-MATCH: aliasing values passed mutably
# Claim: a pointer typed with origin_of(self) may reach every field of self,
# so the compiler rejects reading self._len in the same call. Deriving the
# pointer from the storage field alone (origin_of(self._storage)) compiles.

from std.memory import Allocation, Layout, alloc, dealloc


struct Readings(Movable):
    var _storage: Allocation[Float64]
    var _len: Int

    def __init__(out self):
        self._storage = alloc(Layout[Float64](length=8))
        self._len = 0

    def whole_self_ptr[
        origin: Origin, //
    ](ref[origin] self) -> Pointer[Float64, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    def push_field_precise(mut self, celsius: Float64):
        self._storage.unsafe_ptr().unsafe_offset(self._len).write(celsius)
        self._len += 1

    def push_whole_self(mut self, celsius: Float64):
        self.whole_self_ptr().unsafe_offset(self._len).write(celsius)
        self._len += 1

    def __deinit__(deinit self):
        dealloc(self._storage^)


def main():
    var readings = Readings()
    readings.push_field_precise(21.5)
    readings.push_whole_self(22.0)
