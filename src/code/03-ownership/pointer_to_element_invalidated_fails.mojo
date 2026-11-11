# EXPECT-ERROR: a Pointer to an element used after append
# EXPECT-MATCH: use of invalidated interior reference
# Claim (3.11): `Pointer(to=cells[0])` takes the element's interior origin, so
# invalidation reaches pointers as well as `ref` bindings.


def main():
    var cells: List[Int] = [1, 2, 3, 4]
    var head = Pointer(to=cells[0])
    cells.append(5)
    print(head[])
