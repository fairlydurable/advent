# EXPECT-ERROR: two pointers with one origin passed as dest and src
# EXPECT-MATCH: aliasing values passed mutably to 'dest'
# Claim: exclusivity checking works on origins, not address ranges. Pointers
# into disjoint halves of one allocation still alias as far as the checker
# can tell.
from std.memory import alloc, dealloc, Layout, unsafe_uninit_copy_n


def main():
    var grown = alloc(Layout[Int64](length=6))
    var data = grown.unsafe_ptr()
    for index in range(3):
        data.unsafe_offset(index).write(Int64(index))
    unsafe_uninit_copy_n[overlapping=False](
        dest=data.unsafe_offset(3), src=data, count=3
    )
    dealloc(grown^)
