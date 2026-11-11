# EXPECT-ERROR: reading a binding that only one path initialized
# EXPECT-MATCH: uninitialized value 'timeout_ms'
# Claim: the compiler rejects a read when any path reaching it leaves the
# binding uninitialized. No default value fills the gap.
from std.sys import argv


def main():
    var timeout_ms: Int
    if len(argv()) > 0:
        timeout_ms = 5000
    print(timeout_ms)
