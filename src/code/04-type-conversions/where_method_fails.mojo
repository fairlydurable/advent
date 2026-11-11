# EXPECT-ERROR: calling a method whose `where` clause the type fails
# EXPECT-MATCH: invalid call to 'describe': violated constraint
# Claim: a method can exist only for some instantiations. Method lookup finds
# it, then the `where` clause rejects the call for this element type.
struct Probe[T: AnyType]:
    var hits: Int

    def __init__(out self):
        self.hits = 0

    def describe(self) -> String where conforms_to(Self.T, Writable):
        return "writable payload"


struct RawFrame:
    var bytes: Int


def main():
    var probe = Probe[RawFrame]()
    print(probe.describe())
