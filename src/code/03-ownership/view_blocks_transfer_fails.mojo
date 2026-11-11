# EXPECT-ERROR: the owner moves away while a view of it is still used
# EXPECT-MATCH: use of uninitialized value 'manifest'
# Claim (3.3): a value whose type carries `origin_of(manifest)` counts as a use
# of `manifest` at each of its own uses.


struct Cursor[mut: Bool, //, o: Origin[mut=mut]](ImplicitlyCopyable):
    var target: Pointer[String, Self.o]

    def __init__(out self, ref[Self.o] target: String):
        self.target = Pointer(to=target)


def ship(var manifest: String):
    pass


def main():
    var manifest = String("crates:12")
    var cursor = Cursor(manifest)
    ship(manifest^)
    print(cursor.target[])
