# Claims:
# - Unsafe code that moves an element out of a buffer opens a "hole".
#   If a call that can raise runs while the hole is open, the buffer must
#   still hold valid values when the error leaves the function.
# - A guard whose destructor writes the element back closes the hole on the
#   normal path and on the error path alike.
# - After a raising comparator aborts the sort, the list holds every
#   original element exactly once.
from std.testing import assert_equal, assert_raises, assert_true


struct Hole(Movable):
    var base: Pointer[String, MutUntrackedOrigin]
    var position: Int
    var element: String

    def __init__(
        out self, base: Pointer[String, MutUntrackedOrigin], position: Int
    ):
        self.base = base
        self.position = position
        self.element = base.unsafe_offset(position).unsafe_take_pointee()

    def __deinit__(deinit self):
        self.base.unsafe_offset(self.position).unsafe_write(self.element^)


def insertion_sort(
    mut items: List[String],
    less: Some[def(String, String) raises -> Bool],
) raises:
    var base = items.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    for index in range(1, len(items)):
        var hole = Hole(base, index)
        while hole.position > 0 and less(
            hole.element, base[unsafe_offset=hole.position - 1]
        ):
            base.unsafe_offset(hole.position).unsafe_write_move_from(
                base.unsafe_offset(hole.position - 1)
            )
            hole.position -= 1


def by_hostname(lhs: String, rhs: String) raises -> Bool:
    if lhs == "corrupt-record" or rhs == "corrupt-record":
        raise Error("comparator rejected a record")
    return lhs < rhs


def main() raises:
    var hosts: List[String] = ["web-03", "db-01", "cache-02", "api-04"]
    insertion_sort(hosts, by_hostname)
    assert_equal(hosts, ["api-04", "cache-02", "db-01", "web-03"])

    var original: List[String] = ["web-03", "db-01", "corrupt-record", "api-04"]
    var mixed = original.copy()
    with assert_raises(contains="rejected"):
        insertion_sort(mixed, by_hostname)
    assert_equal(len(mixed), len(original))
    for host in original:
        assert_true(host in mixed)
