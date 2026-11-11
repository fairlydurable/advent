# Claim: the operations that can cause undefined behavior carry an `unsafe_`
# prefix (or live behind `external_call`, `bitcast`, and similar escape
# hatches). This sample uses each one correctly.
from std.ffi import external_call
from std.memory import alloc, dealloc, bitcast, Layout
from std.testing import assert_equal


def main() raises:
    var slots = alloc(Layout[String](length=2))
    var base = slots.unsafe_ptr()

    # Initialize uninitialized memory.
    base.unsafe_write(String("pump-a"))
    base.unsafe_offset(1).unsafe_write(String("pump-b"))

    # Move a value out, leaving its slot uninitialized.
    var first = base.unsafe_take_pointee()

    # Destroy a value in place.
    base.unsafe_offset(1).unsafe_deinit_pointee()

    # Both slots are now uninitialized, so releasing the storage is sound.
    dealloc(slots^)
    # Asserts raise, and a raise between `alloc` and `dealloc` would abandon
    # the allocation, so the checks wait until the storage is gone.
    assert_equal(first, "pump-a")

    # Reinterpret bits.
    var one_bits = bitcast[DType.uint32](Float32(1.0))
    assert_equal(one_bits, 0x3F800000)

    # Call foreign code. The compiler trusts the declared signature.
    var magnitude = external_call["abs", Int32](Int32(-17))
    assert_equal(magnitude, 17)
