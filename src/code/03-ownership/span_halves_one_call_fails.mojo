# EXPECT-ERROR: two halves of one Span passed to one call, one of them mutably
# EXPECT-MATCH: aliasing values passed mutably to 'dest'
# Claim (3.11): subspans keep the parent's origin, so the checker sees two
# halves of one List as the same memory, even when they do not overlap.


def mirror(dest: Span[mut=True, Int, _], src: Span[Int, _]):
    for index in range(len(dest)):
        dest[index] = src[len(src) - 1 - index]


def main():
    var cells: List[Int] = [1, 2, 3, 4]
    var front = Span(cells)[0:2]
    var back = Span(cells)[2:4]
    mirror(front, back)
    print(cells)
