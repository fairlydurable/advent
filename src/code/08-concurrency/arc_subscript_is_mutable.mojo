# Claims:
#   - ArcPointer copies share one heap value, and `arc[]` returns a mutable
#     reference through any copy, even a copy held by an immutable binding.
#   - So ArcPointer makes the reference count thread-safe, not the value:
#     guarding the value against concurrent writes is the program's job.
#   - A copy dies at its last use: after apply_discount() the count drops
#     back to 1 even though `pricing_view` is still in scope.
from std.memory import ArcPointer
from std.testing import assert_equal


def apply_discount(prices: ArcPointer[List[Int]]):
    # `prices` is a read-only argument, yet the subscript hands out a
    # mutable reference to the shared list.
    for ref price in prices[]:
        price -= price // 10


def main() raises:
    var prices: List[Int] = [1200, 450, 990]
    var catalog = ArcPointer(prices^)
    var pricing_view = catalog.copy()
    assert_equal(catalog.count(), 2)
    apply_discount(pricing_view)  # last use of `pricing_view`
    assert_equal(catalog.count(), 1)
    assert_equal(catalog[], [1080, 405, 891])
