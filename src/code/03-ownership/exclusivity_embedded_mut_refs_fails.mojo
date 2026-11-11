# EXPECT-ERROR: two values that each embed a mutable reference to the same List
# EXPECT-MATCH: aliasing values passed mutably
# Claim (3.2): a value that carries a mutable origin counts as a mutable access
# to that origin. Two such values cannot go to one call, even as `imm` arguments.


struct Recorder[o: MutOrigin](Movable):
    var log: Pointer[List[String], Self.o]

    def __init__(out self, ref[Self.o] log: List[String]):
        self.log = Pointer(to=log)


def compare(first: Recorder, second: Recorder) -> Bool:
    return Int(first.log) == Int(second.log)


def main():
    var log = List[String]()
    var intake = Recorder(log)
    var outtake = Recorder(log)
    print(compare(intake, outtake))
