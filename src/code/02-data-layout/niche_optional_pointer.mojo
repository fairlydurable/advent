# Claim: a non-nullable `Pointer` leaves the null address unused, and
# `Optional` stores `None` in that niche, so `Optional[Pointer[...]]` is the
# same size as the pointer.
# Claim: standard library owners built on pointers inherit the niche:
# `ArcPointer`, `OwnedPointer`, `String`, and `List`.
from std.memory import ArcPointer, OwnedPointer
from std.sys import size_of
from std.testing import assert_equal


def main() raises:
    comptime Raw = Pointer[Int, MutUntrackedOrigin]
    assert_equal(size_of[Optional[Raw]](), size_of[Raw]())
    assert_equal(size_of[Optional[ArcPointer[Int]]](), 8)
    assert_equal(size_of[Optional[OwnedPointer[Int]]](), 8)
    assert_equal(size_of[Optional[String]](), size_of[String]())
    assert_equal(size_of[Optional[List[Int]]](), size_of[List[Int]]())

    var cached: Optional[ArcPointer[String]] = None
    assert_equal(Bool(cached), False)
    cached = ArcPointer(String("eu-central"))
    assert_equal(cached.value()[], "eu-central")
