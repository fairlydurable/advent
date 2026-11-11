# EXPECT-ERROR: bitcasting between different total bit widths
# EXPECT-MATCH: same bitwidth
# Claim: bitcast checks at compile time that source and destination have the
# same total width.
from std.memory import bitcast
from std.sys import argv


def main():
    var word = UInt32(len(argv()))
    print(bitcast[DType.uint64](word))
