# Claims (3.6):
# - A struct can own untracked storage and hand out pointers bound to its own
#   origin with `unsafe_mut_cast` plus `unsafe_origin_cast`.
# - Those views keep the owner alive, so its `__deinit__` (which frees the
#   storage) runs only after the last view use.
from std.memory import alloc, dealloc, Layout, ThinAllocation
from std.testing import assert_equal


struct Samples[o: MutOrigin](Movable):
    var raw: Pointer[Float64, MutUntrackedOrigin]
    var count: Int
    var log: Pointer[List[String], Self.o]

    def __init__(out self, count: Int, ref[Self.o] log: List[String]):
        self.raw = alloc(Layout[Float64](length=count)).unsafe_leak()
        self.count = count
        self.log = Pointer(to=log)
        for index in range(count):
            self.raw.unsafe_offset(index).write(Float64(index) * 0.5)

    def view(ref self) -> Pointer[Float64, origin_of(self)]:
        return self.raw.unsafe_mut_cast[
            origin_of(self).mut
        ]().unsafe_origin_cast[origin_of(self)]()

    def __deinit__(deinit self):
        self.log[].append("freed")
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.raw).unsafe_with_layout(
                Layout[Float64](length=self.count)
            )
        )


def main() raises:
    var log = List[String]()
    var samples = Samples(4, log)
    var readings = samples.view()
    readings[unsafe_offset=1] = 9.25
    log.append("wrote")
    var third = readings[unsafe_offset=3]
    log.append("read")
    assert_equal(third, 1.5)
    assert_equal(log, ["wrote", "freed", "read"])
