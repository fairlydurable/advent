# EXPECT-ERROR: the declared origin is all of self, but the body returns one field
# EXPECT-MATCH: incompatible origin
# Claim (3.5): returning a field requires `ref[self.field]`, not `ref[self]`.


struct Roster(Movable):
    var team: String
    var scores: List[Int]

    def __init__(out self):
        self.team = "owls"
        self.scores = [70, 82]

    def scores_ref(mut self) -> ref[self] List[Int]:
        return self.scores


def main():
    var roster = Roster()
    print(len(roster.scores_ref()))
