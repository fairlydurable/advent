# EXPECT-EXIT: nonzero
# Claim: Layout(length=) checks its count at run time and aborts on a
# negative length instead of handing a nonsense size to the allocator.

from std.memory import Layout


def main():
    var requested = -3
    var layout = Layout[Float64](length=requested)
    print(len(layout))
