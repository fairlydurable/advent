# Claim: `unsafe_write()` assumes the slot holds no live value. Writing over
# a live value never runs the old value's destructor, so the old value leaks.
# A leak is not undefined behavior; it is a resource the program never
# releases.
# The lease holds a reference-counted share of a budget, so the count shows
# how many leases are still alive.
from std.memory import alloc, dealloc, ArcPointer, Layout
from std.testing import assert_equal


@fieldwise_init
struct Lease(Movable):
    var budget: ArcPointer[Int]


def main() raises:
    var budget = ArcPointer(5000)
    var slot = alloc(Layout[Lease].single())
    var cell = slot.unsafe_ptr()

    cell.unsafe_write(Lease(budget.copy()))
    cell.unsafe_write(Lease(budget.copy()))  # The first lease never ends.
    cell.unsafe_deinit_pointee()
    dealloc(slot^)

    # One share for `budget`, one for the leaked lease.
    assert_equal(budget.count(), 2)
