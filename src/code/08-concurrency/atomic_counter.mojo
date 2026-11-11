# Claims:
#   - Atomic read-modify-write operations make a shared counter exact:
#     8 threads x 10,000 increments always total 80,000.
#   - `+=` on an Atomic is an atomic fetch_add, not a load followed by a store.
from threads import ThreadArg, erase, run_threads
from std.atomic import Atomic
from std.testing import assert_equal

comptime INCREMENTS_PER_THREAD = 10_000


def count_requests(arg: ThreadArg) abi("C") -> ThreadArg:
    var requests = arg.unsafe_bitcast[Atomic[Int64]]()
    for _ in range(INCREMENTS_PER_THREAD):
        requests[] += 1
    return arg


def main() raises:
    var requests = Atomic[Int64](0)
    run_threads(count_requests, erase(requests), 8)
    assert_equal(requests.load(), 8 * INCREMENTS_PER_THREAD)
