# Claims:
#   - Atomic's static methods operate on any suitably typed pointer, so a
#     plain heap buffer of Int64 can take atomic updates without wrapping
#     each element in an Atomic.
#   - Every concurrent access to those elements must go through the atomic
#     methods. Plain reads happen only after the join.
#   - `histogram` has no later use, so without the deinit() call its life
#     would end at erase() while the threads still read it.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic, Ordering
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal

comptime BUCKETS = 16


struct Histogram(Movable):
    var counts: Pointer[Int64, MutUntrackedOrigin]

    def __init__(out self, counts: Pointer[Int64, MutUntrackedOrigin]):
        self.counts = counts


def record_latencies(arg: ThreadArg) abi("C") -> ThreadArg:
    var counts = arg.unsafe_bitcast[Histogram]()[].counts
    for sample in range(4800):
        var bucket = counts.unsafe_offset(sample % BUCKETS)
        _ = Atomic[Int64].fetch_add[ordering=Ordering.RELAXED](bucket, 1)
    return arg


def main() raises:
    var storage = alloc(Layout[Int64](length=BUCKETS))
    var counts = storage.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    for bucket in range(BUCKETS):
        counts.unsafe_offset(bucket).write(0)

    var histogram = Histogram(counts)
    run_threads(record_latencies, erase(histogram), 6)
    deinit(histogram^)  # keeps `histogram` alive until every thread has joined

    var total = Int64(0)
    var bucket_zero = counts[]
    for bucket in range(BUCKETS):
        total += counts[unsafe_offset=bucket]
    dealloc(storage^)
    assert_equal(bucket_zero, 6 * 4800 // BUCKETS)
    assert_equal(total, 6 * 4800)
