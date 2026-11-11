# Claims (3.11):
# - Recasting one half to `MutUntrackedOrigin` lets one call take both halves.
# - The cast removes that half from lifetime tracking, so the code keeps the
#   owner alive by using `cells` after the call. The halves do not overlap,
#   which is the invariant the cast asserts.
from std.testing import assert_equal


def mirror(dest: Span[mut=True, Int, _], src: Span[Int, _]):
    for index in range(len(dest)):
        dest[index] = src[len(src) - 1 - index]


def main() raises:
    var cells: List[Int] = [1, 2, 3, 4, 5, 6]
    var whole = Span(cells)
    var middle = len(whole) // 2
    var left = whole.unsafe_subspan(offset=0, length=middle)
    var right = Span(
        unsafe_ptr=whole.unsafe_ptr()
        .unsafe_offset(middle)
        .unsafe_origin_cast[MutUntrackedOrigin](),
        length=len(whole) - middle,
    )
    mirror(left, right)
    assert_equal(cells, [6, 5, 4, 4, 5, 6])
