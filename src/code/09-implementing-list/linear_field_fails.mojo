# EXPECT-ERROR: a struct with an Allocation field cannot get a synthesized destructor, because Allocation has no implicit destructor
# EXPECT-MATCH: non-'Deinitable' type 'Allocation
# Claim: storing a linear Allocation in a field forces the struct to say how
# it releases that field. Without a __deinit__, the struct cannot be dropped.

from std.memory import Allocation, Layout, alloc


struct SampleBuffer(Movable):
    var storage: Allocation[Float64]

    def __init__(out self):
        self.storage = alloc(Layout[Float64](length=64))


def main():
    var buffer = SampleBuffer()
    _ = buffer^
