# Claims:
#   - ArcPointer can hold a non-Deinitable payload. Each owner must then be
#     consumed with deinit_with(), and only the last one actually invokes
#     the named destructor.
#   - While a non-Deinitable owner is live, a raising call is rejected: the
#     error path would abandon it. So this sample records what it observes
#     and asserts only after both owners are consumed.
from std.memory import ArcPointer
from std.testing import assert_equal


struct LeaseToken(Movable, not Deinitable):
    """Callers must give it back explicitly; dropping it silently is a compile error."""
    var lease_id: Int
    var returned: Pointer[List[Int], MutUntrackedOrigin]

    def __init__(out self, lease_id: Int, returned: Pointer[List[Int], MutUntrackedOrigin]):
        self.lease_id = lease_id
        self.returned = returned

    def give_back(deinit self):
        self.returned[].append(self.lease_id)


def main() raises:
    var returned = List[Int]()
    var returned_ptr = Pointer(to=returned).unsafe_origin_cast[MutUntrackedOrigin]()
    var lease = ArcPointer(LeaseToken(8812, returned_ptr))
    var holder = lease.copy()
    lease^.deinit_with(LeaseToken.give_back)
    var returned_while_held = len(returned)  # `holder` still owns a reference
    holder^.deinit_with(LeaseToken.give_back)
    assert_equal(returned_while_held, 0)
    assert_equal(returned, [8812])
