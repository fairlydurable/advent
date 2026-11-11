# EXPECT-ERROR: building a Pointer from the literal address 0
# EXPECT-MATCH: Pointer is non-nullable
# Claim: Pointer has no null value. A literal zero address fails at compile
# time; model "no pointer" with Optional[Pointer[...]].
def main():
    var device = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=0)
    print(Int(device))
