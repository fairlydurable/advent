# Claim (3.11): one call can take two fields of the same struct mutably,
# because each field has its own origin.
from std.testing import assert_equal


struct Fixture(Movable):
    var home: List[Int]
    var away: List[Int]

    def __init__(out self):
        self.home = [3, 1, 4]
        self.away = [2]


def rebalance(mut longer: List[Int], mut shorter: List[Int]):
    while len(longer) > len(shorter) + 1:
        shorter.append(longer.pop())


def main() raises:
    var fixture = Fixture()
    rebalance(fixture.home, fixture.away)
    assert_equal(fixture.home, [3, 1])
    assert_equal(fixture.away, [2, 4])
