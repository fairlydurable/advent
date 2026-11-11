# Claims:
#   - BlockingSpinLock records an owner token (BlockingScopedLock uses its
#     own address). unlock() with any other token returns False and leaves
#     the lock held.
#   - The check is a convention about tokens, not a proof about threads:
#     any code that passes the right integer can unlock.
from std.utils.lock import BlockingSpinLock
from std.testing import assert_equal, assert_false, assert_true


def main() raises:
    var lock = BlockingSpinLock()
    comptime SCHEDULER_TOKEN = 4096
    comptime INTRUDER_TOKEN = 8192
    lock.lock(SCHEDULER_TOKEN)
    assert_false(lock.unlock(INTRUDER_TOKEN))
    assert_equal(lock.counter.load(), Int64(SCHEDULER_TOKEN))
    assert_true(lock.unlock(SCHEDULER_TOKEN))
    assert_equal(lock.counter.load(), BlockingSpinLock.UNLOCKED)
