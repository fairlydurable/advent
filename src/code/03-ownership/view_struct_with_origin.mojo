# Claims (3.3):
# - A struct that holds a reference carries the referent's origin as a parameter.
# - The view writes through to the owner, and its type names that owner.
# - `append` takes `self` immutably: the Cursor stays unchanged; the String it
#   points at changes.
from std.testing import assert_equal


struct Cursor[o: MutOrigin](ImplicitlyCopyable):
    var target: Pointer[String, Self.o]

    def __init__(out self, ref[Self.o] target: String):
        self.target = Pointer(to=target)

    def append(self, suffix: String):
        self.target[] += suffix


def main() raises:
    var manifest = String("crates:12")
    var cursor: Cursor[origin_of(manifest)] = Cursor(manifest)
    cursor.append(";drums:3")
    assert_equal(manifest, "crates:12;drums:3")
