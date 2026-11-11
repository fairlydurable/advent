# Claims (3.1):
# - A `ref` binding names an existing value; writes through it change the original.
# - Assigning to a `ref` binding assigns to the referent. It never reseats the binding.
# - An `imm` argument reads the caller's value in place; a `mut` argument writes it.
# - A `ref` argument accepts mutable bindings and immutable values alike.
from std.testing import assert_equal


def label_width(imm label: String) -> Int:
    return label.byte_length()


def stamp(mut label: String):
    label += "#1"


def measured(ref label: String) -> Int:
    return label.byte_length()


def main() raises:
    var crate = String("crate")
    assert_equal(label_width(crate), 5)

    stamp(crate)
    assert_equal(crate, "crate#1")
    assert_equal(measured(crate), 7)
    assert_equal(measured("pallet"), 6)

    ref tag = crate
    tag += "b"
    assert_equal(crate, "crate#1b")

    var spare = String("spare")
    tag = spare  # copies `spare` into `crate`; `tag` still names `crate`
    spare += "-edited"
    assert_equal(crate, "spare")
    assert_equal(spare, "spare-edited")
