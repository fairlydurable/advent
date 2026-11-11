# EXPECT-ERROR: the declared origin is the whole list, but the body returns an element
# EXPECT-MATCH: incompatible origin
# Claim (3.5): `ref[names]` and `ref[names[0]]` are different origins. Element
# references carry the list's interior origin, and the signature must say so.


def first(ref names: List[String]) -> ref[names] String:
    return names[0]


def main():
    var crew: List[String] = ["ada"]
    print(first(crew))
