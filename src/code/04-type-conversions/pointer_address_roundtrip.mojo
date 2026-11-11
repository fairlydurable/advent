# Claim: Int(pointer) yields the address; Pointer(unsafe_from_address=)
# rebuilds a pointer from it. The rebuilt pointer carries only the origin you
# write down, so you vouch for the target staying alive.
# Claim: unsafe_offset(1) advances by size_of[T]() bytes.
from std.sys import size_of
from std.testing import assert_equal


def main() raises:
    var pressure = 5500
    var gauge = Pointer(to=pressure)
    var address = Int(gauge)
    var rebuilt = Pointer[Int, origin_of(pressure)](unsafe_from_address=address)
    rebuilt[] += 1
    assert_equal(pressure, 5501)
    assert_equal(Int(gauge.unsafe_offset(1)) - address, size_of[Int]())
