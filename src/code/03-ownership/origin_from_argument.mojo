# Claims (3.3):
# - `-> ref[names[0]] String` ties the result to the list's element origin.
# - Mutability follows the argument: a mutable list yields a writable reference,
#   an immutable one yields a read-only reference, from one function.
from std.testing import assert_equal


def first(ref names: List[String]) -> ref[names[0]] String:
    return names[0]


def first_length(names: List[String]) -> Int:
    return first(names).byte_length()


def main() raises:
    var crew: List[String] = ["ada", "grace"]
    first(crew) += "!"
    assert_equal(crew[0], "ada!")
    assert_equal(first_length(crew), 4)
