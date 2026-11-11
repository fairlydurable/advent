# EXPECT-ERROR: returning a list element under the origin of the whole list
# EXPECT-MATCH: incompatible origin
# Claim: a returned reference must name the origin it really comes from. A
# list element lives in the list's heap storage, which has its own origin,
# so `ref[self.readings]` does not cover it.
struct Recorder(Movable):
    var readings: List[Int]

    def __init__(out self):
        self.readings = [5500]

    def latest(ref self) -> ref[self.readings] Int:
        return self.readings[len(self.readings) - 1]


def main():
    var recorder = Recorder()
    print(recorder.latest())
