# EXPECT-ERROR: a ref result without an origin specifier
# EXPECT-MATCH: requires an origin specifier
# Claim (3.5): Mojo never guesses a returned reference's origin; the signature
# must name it.


def first(ref names: List[String]) -> ref String:
    return names[0]


def main():
    var crew: List[String] = ["ada"]
    print(first(crew))
