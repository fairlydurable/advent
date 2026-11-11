# EXPECT-ERROR: an abi("C") function cannot be marked raises, because C has no way to receive a Mojo error
# EXPECT-MATCH: may not be marked 'raises'
# Claim: the compiler rejects a raising abi("C") function; convert errors to
# a status value inside the callback instead.

from std.ffi import c_int


def parse_channel(text: Int32) abi("C") raises -> c_int:
    if text < 0:
        raise Error("negative channel")
    return text


def main():
    _ = parse_channel
