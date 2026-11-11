# EXPECT-ERROR: writing through a reference derived from an immutable argument
# EXPECT-MATCH: must be mutable
# Claim (3.3): the same `ref`-returning function gives back a read-only
# reference when its argument is immutable.


def first(ref names: List[String]) -> ref[names[0]] String:
    return names[0]


def shout(names: List[String]):
    first(names) += "!"


def main():
    var crew: List[String] = ["ada"]
    shout(crew)
