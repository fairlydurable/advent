# Claim: `alloc` of a zero-sized type never calls the allocator; it hands
# back a well-aligned dangling pointer, and `dealloc` of it frees nothing.
# Claim: pointer arithmetic on a zero-sized type doesn't move the pointer,
# so every element shares one address.
# Claim: a List of zero-sized values still counts its elements.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


@fieldwise_init
struct Tick(Copyable):
    pass


def main() raises:
    var ticks = alloc(Layout[Tick](length=1_000_000))
    var first = ticks.unsafe_ptr()
    var last = first.unsafe_offset(999_999)
    var same_address = Int(first) == Int(last)
    var length = len(ticks)
    dealloc(ticks^)
    assert_equal(same_address, True)
    assert_equal(length, 1_000_000)

    var log = List[Tick]()
    for _ in range(500):
        log.append(Tick())
    assert_equal(len(log), 500)
