# Claims:
#   - The reference-count release pattern: every owner decrements with
#     RELEASE; the owner that takes the count from 1 to 0 issues an ACQUIRE
#     fence before touching the shared data.
#   - That pairing guarantees the last owner sees every write any other
#     owner made before its own decrement, so exactly one thread finds all
#     8 slots filled.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering, fence
from std.testing import assert_equal

comptime OWNERS = 8


struct SharedReport(Movable):
    var owners: Atomic[UInt64]
    var next_slot: Atomic[Int64]
    var shard_totals: List[Int]
    var final_total: Int
    var cleanups: Atomic[Int64]

    def __init__(out self):
        self.owners = Atomic[UInt64](OWNERS)
        self.next_slot = Atomic[Int64](0)
        self.shard_totals = List[Int](length=OWNERS, fill=0)
        self.final_total = 0
        self.cleanups = Atomic[Int64](0)


def finish_shard(arg: ThreadArg) abi("C") -> ThreadArg:
    var report = arg.unsafe_bitcast[SharedReport]()
    var slot = Int(report[].next_slot.fetch_add(1))
    report[].shard_totals[slot] = (slot + 1) * 1000  # plain write

    if report[].owners.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
        return arg  # not the last owner
    fence[ordering=Ordering.ACQUIRE]()
    var total = 0
    for index in range(OWNERS):
        total += report[].shard_totals[index]
    report[].final_total = total
    report[].cleanups += 1
    return arg


def main() raises:
    var report = SharedReport()
    run_threads(finish_shard, erase(report), OWNERS)
    assert_equal(report.cleanups.load(), 1)
    assert_equal(report.final_total, 36000)
