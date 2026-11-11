# Claim: Pointer.write() may overwrite a slot that already holds a value, for
# trivially deinitializable types such as Int64, because no destructor exists
# to skip.
# Claim: an assert can raise, and a raise that skips dealloc() abandons the
# Allocation, so the sample frees the memory before asserting.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


def main() raises:
    var allocation = alloc(Layout[Int64](length=4))
    var counters = allocation.unsafe_ptr()
    for index in range(4):
        counters.unsafe_offset(index).write(Int64(index * 100))
    counters.unsafe_offset(2).write(Int64(250))  # overwrite, no leak possible
    var patched = counters[unsafe_offset=2]
    var last = counters[unsafe_offset=3]
    dealloc(allocation^)  # before any assert: a raise must not skip it
    assert_equal(patched, 250)
    assert_equal(last, 300)
