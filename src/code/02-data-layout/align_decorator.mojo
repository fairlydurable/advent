# Claim: `@align(N)` raises a struct's alignment to at least N bytes, and its
# size rounds up to a multiple of that alignment, so arrays of it put each
# element on its own N-byte boundary.
# Claim: `@align` can't lower alignment below what the fields need.
# Claim: an aligned field passes its alignment to the containing struct.
from std.memory import alloc, dealloc, Layout
from std.sys import size_of, align_of
from std.testing import assert_equal


@align(64)
@fieldwise_init
struct HitCounter:
    var hits: Int


@align(4)
@fieldwise_init
struct WideField:
    var total: Int64


struct Shard:
    var counter: HitCounter
    var shard_id: Int

    def __init__(out self, shard_id: Int):
        self.counter = HitCounter(0)
        self.shard_id = shard_id


def main() raises:
    assert_equal(align_of[HitCounter](), 64)
    assert_equal(size_of[HitCounter](), 64)
    assert_equal(size_of[Array[HitCounter, 4]](), 256)
    assert_equal(align_of[WideField](), 8)
    assert_equal(align_of[Shard](), 64)
    assert_equal(size_of[Shard](), 128)

    var counters = alloc(Layout[HitCounter](length=4))
    var address = Int(counters.unsafe_ptr())
    dealloc(counters^)
    assert_equal(address % 64, 0)  # The heap honors the type's alignment.
