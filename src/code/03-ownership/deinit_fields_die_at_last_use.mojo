# Claims (3.9):
# - Inside `__deinit__`, fields the body never reads die before the body runs,
#   in declaration order.
# - A field the body reads dies right after that read.
# Prints, in order: deinit first, deinit third, body start, reading second,
# deinit second, body end, end.


struct Probe(Movable):
    var label: String

    def __init__(out self, label: String):
        self.label = label

    def __deinit__(deinit self):
        print("deinit", self.label)


struct Trio(Movable):
    var first: Probe
    var second: Probe
    var third: Probe

    def __init__(out self):
        self.first = Probe("first")
        self.second = Probe("second")
        self.third = Probe("third")

    def __deinit__(deinit self):
        print("body start")
        print("reading", self.second.label)
        print("body end")


def main():
    _ = Trio()
    print("end")
