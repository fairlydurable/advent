# EXPECT-ERROR: an Allocation that reaches the end of its life without dealloc
# EXPECT-MATCH: 'allocation' abandoned without being explicitly destroyed
# Claim: Allocation is a linear (not Deinitable) type. Forgetting dealloc() is
# a compile error, not a leak.
from std.memory import alloc, Layout


def main():
    var allocation = alloc(Layout[Int](length=4))
    var slots = allocation.unsafe_ptr()
    slots.write(7)
    print(slots[])
