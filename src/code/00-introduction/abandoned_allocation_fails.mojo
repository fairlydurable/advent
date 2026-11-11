# EXPECT-ERROR: an Allocation is a linear value; dropping it without dealloc is a compile error
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim: the compiler rejects a heap allocation that no path releases.
from std.memory import alloc, Layout


def main():
    var samples = alloc(Layout[Float64](length=256))
    print("reserved", len(samples), "samples")
