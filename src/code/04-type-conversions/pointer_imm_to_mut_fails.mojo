# EXPECT-ERROR: an immutable pointer passed where a mutable one is required
# EXPECT-MATCH: cannot be converted from 'Pointer\[Int, .*\]' to 'MutPointer
# Claim: the implicit conversion runs one way only. Gaining mutability takes
# unsafe_mut_cast, which the compiler cannot check.
def bump(target: MutPointer[Int, _]):
    target[] += 1


def main():
    var pressure = 5500
    var reader = Pointer(to=pressure).as_imm()
    bump(reader)
