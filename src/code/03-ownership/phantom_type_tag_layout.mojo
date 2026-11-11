# Claim (3.10): a phantom type parameter adds no storage; `Id[Customer]` has
# the size of its one `Int` field.
from std.sys import size_of
from std.testing import assert_equal


struct Customer:
    pass


@fieldwise_init
struct Id[Kind: AnyType](ImplicitlyCopyable):
    var value: Int


def main() raises:
    assert_equal(size_of[Id[Customer]](), size_of[Int]())
