# Claims:
# - A Mojo function declared abi("C") passes to C as a function pointer.
# - qsort calls the comparator with const void* arguments; the comparator
#   casts them back to the element type it knows they point at.
# - qsort sorts the List's storage in place through unsafe_ptr().

from std.ffi import c_int, c_size_t, external_call
from std.sys import size_of
from std.testing import assert_equal


def by_latency(
    left: ImmOpaquePointer[ImmUntrackedOrigin],
    right: ImmOpaquePointer[ImmUntrackedOrigin],
) abi("C") -> c_int:
    var left_ms = left.unsafe_bitcast[Float64]()[]
    var right_ms = right.unsafe_bitcast[Float64]()[]
    return c_int(-1) if left_ms < right_ms else c_int(left_ms > right_ms)


def main() raises:
    var latencies_ms: List[Float64] = [12.5, 3.25, 48.0, 7.75, 3.0]
    # void qsort(void *base, size_t count, size_t size,
    #            int (*compare)(const void *, const void *));
    external_call["qsort", NoneType](
        latencies_ms.unsafe_ptr(),
        c_size_t(len(latencies_ms)),
        c_size_t(size_of[Float64]()),
        by_latency,
    )
    assert_equal(latencies_ms, [3.0, 3.25, 7.75, 12.5, 48.0])
