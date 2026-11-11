# EXPECT-ERROR: one value passed to two mut arguments of the same call
# EXPECT-MATCH: aliasing values passed mutably to 'lhs'.*mutably to 'rhs'
# Claim (3.2): two `mut` arguments may not alias each other.


def main():
    var route = String("A7")
    swap(route, route)
    print(route)
