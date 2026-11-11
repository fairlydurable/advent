# Claims (3.11):
# - A method returning `ref[self.scores]` borrows only that field.
# - While the reference lives, other fields stay writable, and even a
#   `mut self` method that touches only `team` compiles.
from std.testing import assert_equal


struct Roster(Movable):
    var team: String
    var scores: List[Int]

    def __init__(out self):
        self.team = "owls"
        self.scores = [70, 82]

    def scores_ref(mut self) -> ref[self.scores] List[Int]:
        return self.scores

    def rename(mut self, team: String):
        self.team = team


def main() raises:
    var roster = Roster()
    ref scores = roster.scores_ref()
    roster.team = "hawks"
    roster.rename("ravens")
    scores.append(91)
    assert_equal(roster.team, "ravens")
    assert_equal(roster.scores, [70, 82, 91])
