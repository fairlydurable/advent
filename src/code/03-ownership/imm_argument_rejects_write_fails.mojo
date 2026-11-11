# EXPECT-ERROR: an imm (default) argument is read-only inside the callee
# EXPECT-MATCH: must be mutable
# Claim (3.1): the default argument convention is `imm`; writing to it is a compile error.


def stamp(label: String):
    label += "#1"


def main():
    var crate = String("crate")
    stamp(crate)
