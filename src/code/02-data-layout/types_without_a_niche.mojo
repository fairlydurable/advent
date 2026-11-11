# Claim: a type that uses every bit pattern has no niche, so `Optional` adds
# a tag and the padding its alignment requires: `Int`, `Float64`, and even
# `Bool` grow.
# Claim: one niche serves one `Optional`; a nested `Optional` pays a tag.
# Claim: a user struct doesn't get a niche from its fields, even when a
# field is a `String`.
from std.sys import size_of
from std.testing import assert_equal


@fieldwise_init
struct Route(Movable):
    var destination: String
    var hops: Int


def main() raises:
    assert_equal(size_of[Optional[Int]](), 16)
    assert_equal(size_of[Optional[Float64]](), 16)
    assert_equal(size_of[Optional[Bool]](), 2)

    comptime Raw = Pointer[Int, MutUntrackedOrigin]
    assert_equal(size_of[Optional[Optional[Raw]]](), 16)
    assert_equal(size_of[Optional[Optional[String]]](), 32)

    assert_equal(size_of[Route](), 32)
    assert_equal(size_of[Optional[Route]](), 40)
