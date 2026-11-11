# Claims:
# - `forget_deinit` consumes a value without running its destructor, or the
#   destructors of any of its fields.
# - It is a safe function: skipping a destructor can leak, but cannot by
#   itself corrupt memory.
from std.memory import ArcPointer, forget_deinit
from std.testing import assert_equal


struct Lease(Movable):
    var holder: String
    var releases: ArcPointer[Int]

    def __init__(out self, holder: String, releases: ArcPointer[Int]):
        self.holder = holder
        self.releases = releases

    def __deinit__(deinit self):
        self.releases[] += 1


struct Tenancy(Movable):
    var primary: Lease
    var backup: Lease

    def __init__(out self, releases: ArcPointer[Int]):
        self.primary = Lease("node-a", releases)
        self.backup = Lease("node-b", releases)


def main() raises:
    var releases = ArcPointer(0)

    _ = Tenancy(releases)
    assert_equal(releases[], 2)

    var forgotten = Tenancy(releases)
    forget_deinit(forgotten^)
    assert_equal(releases[], 2)
    # Each forgotten Lease still holds an ArcPointer copy, so the counter's
    # strong count stays above one: the leak is observable.
    assert_equal(releases.count(), 3)
