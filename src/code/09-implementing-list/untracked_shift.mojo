# Claims:
# - Casting to MutUntrackedOrigin lets one buffer act as both dest and src
#   of an overlapping move.
# - overlapping=True moves back to front when dest sits above src, so no
#   element overwrites one that has not moved yet.

from std.memory import unsafe_uninit_move_n
from std.testing import assert_equal


def shift_right(mut storage: List[Int], count: Int):
    var data = storage.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    unsafe_uninit_move_n[overlapping=True](
        dest=data.unsafe_offset(1), src=data.unsafe_offset(0), count=count
    )


def main() raises:
    var ports: List[Int] = [8080, 8081, 8082, 0]
    shift_right(ports, 3)
    ports[0] = 443  # slot 0 still holds its old bits; overwrite it
    assert_equal(ports, [443, 8080, 8081, 8082])
