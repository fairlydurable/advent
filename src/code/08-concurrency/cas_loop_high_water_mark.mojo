# Claims:
#   - Any read-modify-write operation can be built from a compare_exchange
#     loop. Here: an atomic maximum.
#   - A weak compare_exchange may fail spuriously, so it belongs only
#     inside a retry loop, where a spurious failure costs one more pass.
#   - The hand-built loop and Atomic.max() agree across 8 threads.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering
from std.testing import assert_equal


struct QueueStats(Movable):
    var deepest_by_loop: Atomic[Int64]
    var deepest_by_max: Atomic[Int64]
    var next_thread: Atomic[Int64]

    def __init__(out self):
        self.deepest_by_loop = Atomic[Int64](0)
        self.deepest_by_max = Atomic[Int64](0)
        self.next_thread = Atomic[Int64](0)


def raise_to(mut mark: Atomic[Int64], depth: Int64):
    var observed = mark.load[ordering=Ordering.RELAXED]()
    while observed < depth:
        if mark.compare_exchange[
            success_ordering=Ordering.RELAXED,
            failure_ordering=Ordering.RELAXED,
            weak=True,
        ](observed, depth):
            return


def sample_queue_depths(arg: ThreadArg) abi("C") -> ThreadArg:
    var stats = arg.unsafe_bitcast[QueueStats]()
    var thread_number = Int(stats[].next_thread.fetch_add(1))
    for step in range(1000):
        var depth = Int64((step * 37 + thread_number * 101) % 4096)
        raise_to(stats[].deepest_by_loop, depth)
        stats[].deepest_by_max.max(depth)
    return arg


def main() raises:
    var stats = QueueStats()
    run_threads(sample_queue_depths, erase(stats), 8)
    assert_equal(stats.deepest_by_loop.load(), 4095)
    assert_equal(stats.deepest_by_max.load(), stats.deepest_by_loop.load())
