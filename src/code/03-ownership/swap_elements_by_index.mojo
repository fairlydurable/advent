# Claim (3.11): `List.swap_elements` takes the list once and two indices, so it
# sidesteps the aliasing check that rejects `swap(temps[0], temps[2])`.
# `Span.swap_elements` does the same on a view, and raises on a bad index.
from std.testing import assert_equal


def main() raises:
    var temps: List[Int] = [12, 18, 25]
    temps.swap_elements(0, 2)
    assert_equal(temps, [25, 18, 12])

    var view = Span(temps)
    view.swap_elements(0, 1)
    assert_equal(temps, [18, 25, 12])
