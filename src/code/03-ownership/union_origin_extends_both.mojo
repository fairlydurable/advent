# Claim (3.4): a reference with a union origin keeps every member alive, even
# the one the function did not pick. `backup` outlives the last use of `chosen`.
# Prints, in order: chose primary, deinit backup, deinit primary, end.


struct Probe(Movable):
    var label: String

    def __init__(out self, label: String):
        self.label = label

    def __deinit__(deinit self):
        print("deinit", self.label)


def pick[
    o1: Origin, o2: Origin, //
](use_first: Bool, ref[o1] first: Probe, ref[o2] second: Probe) -> ref[
    first, second
] Probe:
    if use_first:
        return first
    return second


def main():
    var primary = Probe("primary")
    var backup = Probe("backup")
    ref chosen = pick(True, primary, backup)
    print("chose", chosen.label)
    print("end")
