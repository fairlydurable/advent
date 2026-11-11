# Claims (3.8):
# - An `@implicit` constructor from `Cursor` to `Cursor[ImmOrigin(other.o)]`
#   gives a user view the mutable-to-immutable conversion.
# - The original mutable view stays usable for writes.
from std.testing import assert_equal


struct Cursor[mut: Bool, //, o: Origin[mut=mut]](ImplicitlyCopyable):
    var target: Pointer[String, Self.o]

    def __init__(out self, ref[Self.o] target: String):
        self.target = Pointer(to=target)

    @implicit
    def __init__(other: Cursor, out self: Cursor[ImmOrigin(other.o)]):
        self.target = other.target


def peek[o: ImmOrigin](cursor: Cursor[o]) -> Int:
    return cursor.target[].byte_length()


def main() raises:
    var city = String("Quito")
    var cursor = Cursor(city)
    assert_equal(peek(cursor), 5)
    cursor.target[] += "!"
    assert_equal(city, "Quito!")
