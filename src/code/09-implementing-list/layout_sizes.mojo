# Claims:
# - A ThinAllocation is one pointer wide; an Allocation adds the element
#   count from its Layout, so it is two words.
# - Allocation plus a length field makes a three-word list header, the same
#   size as the standard List.
# - len() of an Allocation reports the capacity its Layout recorded.
# - Optional[Allocation] costs nothing extra: the null pointer is the niche.

from std.memory import Allocation, Layout, ThinAllocation, alloc, dealloc
from std.sys import size_of
from std.testing import assert_equal


struct MyList[T: AnyType](not Deinitable):  # layout only, never instantiated
    var _storage: Allocation[Self.T]
    var _len: Int


def main() raises:
    comptime word = size_of[Int]()
    assert_equal(size_of[ThinAllocation[Float64]](), word)
    assert_equal(size_of[Allocation[Float64]](), 2 * word)
    assert_equal(size_of[MyList[Float64]](), 3 * word)
    assert_equal(size_of[List[Float64]](), 3 * word)
    assert_equal(size_of[Optional[Allocation[Float64]]](), 2 * word)

    var samples = alloc(Layout[Float64](length=48))
    var capacity = len(samples)
    dealloc(samples^)
    assert_equal(capacity, 48)
