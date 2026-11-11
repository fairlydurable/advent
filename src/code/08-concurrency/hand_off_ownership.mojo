# Claims:
#   - Handing a value to another thread means moving it into memory that
#     both threads can address, then letting exactly one side destroy it.
#   - The receiving thread takes the value out with unsafe_take_pointee(),
#     becomes its sole owner, and its destruction happens on that thread.
#   - The sender must not touch the moved-out slot again until the join.
#   - Assertions run after `dealloc`: a raising call while the linear
#     Allocation is live would leave it unconsumed on the error path, and
#     the compiler rejects that.
from threads import ThreadArg, spawn, join
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


struct Batch(Movable):
    var orders: List[Int]
    var checksum: Int

    def __init__(out self, var orders: List[Int]):
        self.orders = orders^
        self.checksum = 0


def process_batch(arg: ThreadArg) abi("C") -> ThreadArg:
    var slot = arg.unsafe_bitcast[Batch]()
    var batch = slot.unsafe_take_pointee()  # this thread owns the batch now
    var checksum = 0
    for order_id in batch.orders:
        checksum += order_id
    # Leave the result where the sender can find it. The orders List dies
    # here, on this thread, when `batch` reaches its last use.
    slot.unsafe_write(Batch(List[Int]()))
    slot[].checksum = checksum
    return arg


def main() raises:
    var storage = alloc(Layout[Batch].single())
    var slot = storage.unsafe_ptr()
    slot.unsafe_write(Batch([10452, 10453, 10457, 10460]))

    var erased = slot.unsafe_origin_cast[MutUntrackedOrigin]().unsafe_bitcast[NoneType]()
    join(spawn(process_batch, erased))

    var checksum = slot[].checksum
    var orders_left = len(slot[].orders)
    slot.unsafe_deinit_pointee()
    dealloc(storage^)
    assert_equal(checksum, 41822)
    assert_equal(orders_left, 0)
