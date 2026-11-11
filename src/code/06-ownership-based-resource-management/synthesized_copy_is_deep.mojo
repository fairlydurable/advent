# Claims:
# - Declaring `Copyable` on a struct whose fields are all Copyable gets a
#   synthesized copy constructor that copies each field.
# - Copying a struct that holds a List copies the List's elements, so the two
#   values share no storage.
# - Every struct is Movable without declaring it.
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Playlist(Copyable):
    var title: String
    var track_ids: List[Int]


struct Plain:
    var count: Int


def main() raises:
    var original = Playlist("focus", [4021, 4022, 4030])
    var remix = original.copy()
    remix.track_ids.append(5100)
    assert_equal(len(original.track_ids), 3)
    assert_equal(len(remix.track_ids), 4)
    assert_true(
        original.track_ids.unsafe_ptr() != remix.track_ids.unsafe_ptr()
    )
    comptime assert conforms_to(Plain, Movable)
