# Claim (3.6): copying an untracked pointer field out of its owner is the
# owner's last use when nothing else follows. The owner's `__deinit__` frees
# the storage before the next statement runs. This sample stops at the copy;
# reading through `raw` afterward would be undefined behavior.
from std.memory import alloc, dealloc, Layout, ThinAllocation
from std.testing import assert_equal


struct Samples[o: MutOrigin](Movable):
    var raw: Pointer[Float64, MutUntrackedOrigin]
    var log: Pointer[List[String], Self.o]

    def __init__(out self, ref[Self.o] log: List[String]):
        self.raw = alloc(Layout[Float64](length=2)).unsafe_leak()
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("freed")
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.raw).unsafe_with_layout(
                Layout[Float64](length=2)
            )
        )


def main() raises:
    var log = List[String]()
    var samples = Samples(log)
    var raw = samples.raw
    log.append("copied pointer")
    _ = Int(raw)
    assert_equal(log, ["freed", "copied pointer"])
