# Claims:
#   - The stdlib's BlockingSpinLock guards no data of its own: it is a bare
#     flag, and the program decides which memory it protects.
#   - BlockingScopedLock locks in __enter__ and unlocks in __exit__, so a
#     `with` block is the critical section.
#   - 8 threads x 5,000 increments of a plain Int under the lock total 40,000.
from threads import ThreadArg, erase, run_threads
from std.utils.lock import BlockingScopedLock, BlockingSpinLock
from std.testing import assert_equal


struct Ledger(Movable):
    var lock: BlockingSpinLock
    var entries: Int

    def __init__(out self):
        self.lock = BlockingSpinLock()
        self.entries = 0


def post_entries(arg: ThreadArg) abi("C") -> ThreadArg:
    var ledger = arg.unsafe_bitcast[Ledger]()
    for _ in range(5_000):
        with BlockingScopedLock(ledger[].lock):
            ledger[].entries += 1
    return arg


def main() raises:
    var ledger = Ledger()
    run_threads(post_entries, erase(ledger), 8)
    assert_equal(ledger.entries, 40_000)
