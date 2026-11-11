# EXPECT-ERROR: a call that can raise between alloc and dealloc abandons the allocation on the error path
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim: the compiler checks every exit path, including the hidden one that
# each raising call adds, for a live Allocation.

from std.memory import Layout, alloc, dealloc


def parse_port(text: String) raises -> Int:
    return Int(text)


def main() raises:
    var ports = alloc(Layout[Int].single())
    ports.unsafe_ptr().write(parse_port("8080"))  # can raise
    dealloc(ports^)
