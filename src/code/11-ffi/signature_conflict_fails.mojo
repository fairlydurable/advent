# EXPECT-ERROR: two external_call sites that give one C symbol different Mojo types conflict
# EXPECT-MATCH: existing function with conflicting signature
# Claim: external_call declares the C symbol at each call site, and every
# declaration of one symbol in the program must agree, including ones inside
# the standard library. Pointer and Optional[Pointer] count as different
# types even though they share a layout.

from std.ffi import c_int, c_long, external_call


def main():
    var offset = external_call["abs", c_int](c_int(-40))
    var wide = external_call["abs", c_long](c_long(-40))
    print(offset, wide)
