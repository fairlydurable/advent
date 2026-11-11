# Claims:
#   - Any number of threads may read the same List at once, as long as no
#     thread writes to it. Nothing in the type system states or checks this;
#     the program upholds it.
#   - Each worker writes only its own result slot, so the writes are
#     disjoint and need no synchronization before the join.
from threads import ThreadArg, erase, spawn, join
from std.testing import assert_equal

comptime WORKERS = 4


struct Stripe(Movable):
    var readings: Pointer[List[Int], ImmUntrackedOrigin]
    var first: Int
    var stride: Int
    var total: Int

    def __init__(out self, readings: Pointer[List[Int], ImmUntrackedOrigin], first: Int):
        self.readings = readings
        self.first = first
        self.stride = WORKERS
        self.total = 0


def sum_stripe(arg: ThreadArg) abi("C") -> ThreadArg:
    var stripe = arg.unsafe_bitcast[Stripe]()
    ref readings = stripe[].readings[]
    var position = stripe[].first
    while position < len(readings):
        stripe[].total += readings[position]
        position += stripe[].stride
    return arg


def main() raises:
    var latencies_ms = List[Int](capacity=1000)
    for index in range(1000):
        latencies_ms.append(index % 97)
    var shared = Pointer(to=latencies_ms).as_imm().unsafe_origin_cast[ImmUntrackedOrigin]()

    var stripes = List[Stripe](capacity=WORKERS)
    for worker in range(WORKERS):
        stripes.append(Stripe(shared, worker))
    var handles = List[Int]()
    for worker in range(WORKERS):
        handles.append(spawn(sum_stripe, erase(stripes[worker])))
    for handle in handles:
        join(handle)

    var expected = 0
    for latency in latencies_ms:
        expected += latency
    var combined = 0
    for worker in range(WORKERS):
        combined += stripes[worker].total
    assert_equal(combined, expected)
