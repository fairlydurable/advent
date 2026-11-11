# EXPECT-ERROR: an abi("C") function cannot capture local variables, because a C function pointer has nowhere to carry them
# EXPECT-MATCH: cannot capture variables
# Claim: the compiler rejects a capturing abi("C") function; pass state
# through a void* context argument instead (callback_with_context.mojo).

from std.ffi import c_int


def main():
    var descending = True

    def by_latency(
        left: ImmOpaquePointer[ImmUntrackedOrigin],
        right: ImmOpaquePointer[ImmUntrackedOrigin],
    ) abi("C") {imm descending} -> c_int:
        var left_ms = left.unsafe_bitcast[Float64]()[]
        var right_ms = right.unsafe_bitcast[Float64]()[]
        return c_int(left_ms < right_ms) if descending else c_int(
            left_ms > right_ms
        )

    _ = by_latency
