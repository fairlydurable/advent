# EXPECT-ERROR: the storage owner moves away while a bound view is still used
# EXPECT-MATCH: use of uninitialized value 'samples'
# Claim (3.6): once a raw pointer carries `origin_of(self)`, the ordinary
# ownership rules protect it.
from std.memory import alloc, dealloc, Layout, ThinAllocation


struct Samples(Movable):
    var raw: Pointer[Float64, MutUntrackedOrigin]
    var count: Int

    def __init__(out self, count: Int):
        self.raw = alloc(Layout[Float64](length=count)).unsafe_leak()
        self.count = count
        for index in range(count):
            self.raw.unsafe_offset(index).write(Float64(index))

    def view(ref self) -> Pointer[Float64, origin_of(self)]:
        return self.raw.unsafe_mut_cast[
            origin_of(self).mut
        ]().unsafe_origin_cast[origin_of(self)]()

    def __deinit__(deinit self):
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.raw).unsafe_with_layout(
                Layout[Float64](length=self.count)
            )
        )


def archive(var samples: Samples):
    pass


def main():
    var samples = Samples(4)
    var readings = samples.view()
    archive(samples^)
    print(readings[])
