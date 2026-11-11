# EXPECT-ERROR: a user view type does not convert from mutable to immutable origin
# EXPECT-MATCH: cannot be converted from 'Cursor
# Claim (3.8): origin parameters are invariant. A struct gets the
# mutable-to-immutable conversion only if it declares one.


struct Cursor[mut: Bool, //, o: Origin[mut=mut]](ImplicitlyCopyable):
    var target: Pointer[String, Self.o]

    def __init__(out self, ref[Self.o] target: String):
        self.target = Pointer(to=target)


def peek[o: ImmOrigin](cursor: Cursor[o]) -> Int:
    return cursor.target[].byte_length()


def main():
    var city = String("Quito")
    var cursor = Cursor(city)
    print(peek(cursor))
