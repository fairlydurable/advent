# EXPECT-ERROR: dereferencing an Allocation's pointer after dealloc consumed it
# EXPECT-MATCH: use of uninitialized value 'block'
# Claim (3.6): `Allocation.unsafe_ptr()` returns a pointer whose origin is the
# Allocation, so a use-after-free through it fails to compile.
from std.memory import alloc, dealloc, Layout


def main():
    var block = alloc(Layout[Int](length=2))
    var cursor = block.unsafe_ptr()
    cursor.write(7)
    dealloc(block^)
    print(cursor[])
