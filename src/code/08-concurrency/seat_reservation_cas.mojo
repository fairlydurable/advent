# Claims:
#   - A race condition is a logic bug, not a data race: a check-then-act
#     sequence of two individually atomic operations can still oversell.
#   - A compare_exchange loop makes the check and the act one atomic step,
#     so 8 threads competing for 500 seats sell exactly 500 and never more.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic
from std.testing import assert_equal

comptime SEAT_CAPACITY = 500
comptime ATTEMPTS_PER_THREAD = 200


struct BoxOffice(Movable):
    var seats_sold: Atomic[Int64]
    var refusals: Atomic[Int64]

    def __init__(out self):
        self.seats_sold = Atomic[Int64](0)
        self.refusals = Atomic[Int64](0)

    def try_reserve(mut self) -> Bool:
        var observed = self.seats_sold.load()
        while observed < SEAT_CAPACITY:
            # On failure, compare_exchange stores the current value into
            # `observed`, so the loop re-checks capacity against fresh data.
            if self.seats_sold.compare_exchange(observed, observed + 1):
                return True
        self.refusals += 1
        return False


def sell_seats(arg: ThreadArg) abi("C") -> ThreadArg:
    var office = arg.unsafe_bitcast[BoxOffice]()
    for _ in range(ATTEMPTS_PER_THREAD):
        _ = office[].try_reserve()
    return arg


def main() raises:
    var office = BoxOffice()
    run_threads(sell_seats, erase(office), 8)
    assert_equal(office.seats_sold.load(), SEAT_CAPACITY)
    assert_equal(office.refusals.load(), 8 * ATTEMPTS_PER_THREAD - SEAT_CAPACITY)
