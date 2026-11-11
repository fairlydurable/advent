# Claim: MaybeUninit[T] has the same size as T.
# Claim: MaybeUninit[T] conforms to Deinitable only when T is trivially
# deinitializable; the conformance carries a `where` condition.
from std.memory import MaybeUninit
from std.sys import size_of
from std.testing import assert_equal, assert_true, assert_false


def main() raises:
    assert_equal(size_of[MaybeUninit[String]](), size_of[String]())
    assert_equal(size_of[MaybeUninit[Float64]](), 8)
    assert_true(conforms_to(MaybeUninit[Int], Deinitable))
    assert_false(conforms_to(MaybeUninit[String], Deinitable))
