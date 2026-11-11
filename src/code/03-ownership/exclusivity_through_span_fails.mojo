# EXPECT-ERROR: a mutable Span and its List passed to the same call
# EXPECT-MATCH: aliasing values passed mutably to 'dest'.*immutably to 'src'
# Claim (3.2): exclusivity checking sees references embedded inside values. A
# `Span` carries the List's origin, so `Span(cells)` and `cells` alias.


def double_into(dest: Span[mut=True, Int, _], src: List[Int]):
    for index in range(len(dest)):
        dest[index] = src[index] * 2


def main():
    var cells: List[Int] = [3, 4]
    double_into(Span(cells), cells)
    print(cells)
