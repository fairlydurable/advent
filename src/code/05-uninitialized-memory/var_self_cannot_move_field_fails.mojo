# EXPECT-ERROR: a `var self` method cannot take a field out of self
# EXPECT-MATCH: destroyed out of the middle of a value
# Claim: `var self` owns the value but still has to destroy it whole, so
# moving a field out leaves a hole. Use `deinit self` to take fields apart.
struct Recorder(Movable):
    var samples: List[Int]

    def __init__(out self):
        self.samples = []

    def finish(var self) -> List[Int]:
        return self.samples^


def main():
    var recorder = Recorder()
    print(len(recorder^.finish()))
