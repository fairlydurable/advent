# EXPECT-ERROR: two pointers derived from the same tracked mutable origin cannot both go to a call that takes them mutably
# EXPECT-MATCH: aliasing values passed mutably to 'dest' argument and passed mutably to 'src' argument
# Claim: the exclusivity checker does not know that dest and src address
# different slots, so shifting elements inside one buffer through tracked
# pointers fails. Casting the base pointer to MutUntrackedOrigin first (as
# MyList.insert and the standard List do) takes the call out of the checker's
# view and makes the overlap your responsibility.

from std.memory import Layout, alloc, dealloc, unsafe_uninit_move_n


def shift_right(mut storage: List[Int], count: Int):
    var data = storage.unsafe_ptr()  # origin: origin_of(storage), mutable
    unsafe_uninit_move_n[overlapping=True](
        dest=data.unsafe_offset(1), src=data.unsafe_offset(0), count=count
    )


def main():
    var ports: List[Int] = [8080, 8081, 8082, 0]
    shift_right(ports, 3)
