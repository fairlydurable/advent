# EXPECT-ERROR: a function without abi("C") does not convert to a C function-pointer type
# EXPECT-MATCH: cannot implicitly convert .* value to 'Comparator'
# Claim: external_call takes its arguments as an untyped pack and checks
# nothing about a callback's calling convention. Naming the C function type
# with comptime and storing the callback in it first makes the compiler
# check the ABI.

from std.ffi import c_int

comptime Comparator = def(
    ImmOpaquePointer[ImmUntrackedOrigin], ImmOpaquePointer[ImmUntrackedOrigin]
) thin abi("C") -> c_int


def by_latency(
    left: ImmOpaquePointer[ImmUntrackedOrigin],
    right: ImmOpaquePointer[ImmUntrackedOrigin],
) -> c_int:  # missing abi("C")
    var left_ms = left.unsafe_bitcast[Float64]()[]
    var right_ms = right.unsafe_bitcast[Float64]()[]
    return c_int(-1) if left_ms < right_ms else c_int(left_ms > right_ms)


def main():
    var compare: Comparator = by_latency
    _ = compare
