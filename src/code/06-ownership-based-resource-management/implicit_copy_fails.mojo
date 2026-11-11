# EXPECT-ERROR: a Copyable type that is not ImplicitlyCopyable needs an explicit copy or transfer
# EXPECT-MATCH: cannot be implicitly copied
# Claim: `Copyable` alone does not let `=` copy a value; write `.copy()` or `^`.


@fieldwise_init
struct Firmware(Copyable):
    var image: List[UInt8]


def main():
    var shipped = Firmware([0x7F, 0x45, 0x4C, 0x46])
    var staged = shipped
    print(len(staged.image), len(shipped.image))
