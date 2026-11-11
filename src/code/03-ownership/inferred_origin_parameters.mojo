# Claims (3.5):
# - The compiler infers origins after `//` from the arguments at each call.
# - A bare `ref` argument infers an anonymous origin; `ref[left, right]` names it.
# - The result is mutable because both arguments are mutable.
from std.testing import assert_equal


def longest[
    o1: Origin, o2: Origin, //
](ref[o1] left: String, ref[o2] right: String) -> ref[left, right] String:
    if left.byte_length() >= right.byte_length():
        return left
    return right


def shorter(ref left: String, ref right: String) -> ref[left, right] String:
    if left.byte_length() < right.byte_length():
        return left
    return right


def main() raises:
    var harbor = String("harbor")
    var bay = String("bay")
    longest(harbor, bay) += "!"
    shorter(harbor, bay) += "?"
    assert_equal(harbor, "harbor!")
    assert_equal(bay, "bay?")
