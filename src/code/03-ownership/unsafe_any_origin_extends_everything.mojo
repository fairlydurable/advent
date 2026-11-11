# Claim (3.6): while a pointer with `UnsafeAnyOrigin` lives, every value in
# scope stays alive, including values it never pointed at and values created
# after it. ASAP destruction resumes after its last use.
# Prints, in order: pointer made, filler made, reading anchor,
# then the three deinit lines (filler, unrelated, anchor), then end.


struct Probe(Movable):
    var label: String

    def __init__(out self, label: String):
        self.label = label

    def __deinit__(deinit self):
        print("deinit", self.label)


def main():
    var anchor = Probe("anchor")
    var unrelated = Probe("unrelated")
    var wildcard = Pointer(to=anchor).as_unsafe_any_origin()
    print("pointer made")
    var filler = Probe("filler")
    print("filler made")
    print("reading", wildcard[].label)
    print("end")
