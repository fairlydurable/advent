# EXPECT-ERROR: distance between pointers is undefined for a zero-sized type, so the call fails to instantiate
# EXPECT-MATCH: requires a non-zero-sized pointee type
# Claim: `offset_from` rejects zero-sized pointee types at compile time,
# since every element shares one address.
from std.memory import alloc, dealloc, Layout


@fieldwise_init
struct Tick(Copyable):
    pass


def main():
    var ticks = alloc(Layout[Tick](length=8))
    var first = ticks.unsafe_ptr()
    print(first.unsafe_offset(5).offset_from(first))
    dealloc(ticks^)
