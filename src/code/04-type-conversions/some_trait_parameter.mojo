# Claim: Some[Trait] accepts any conforming type. Each call site instantiates
# the function for its concrete argument type; no boxing or dynamic dispatch
# takes place.
from std.testing import assert_equal


def render(value: Some[Writable]) -> String:
    return String(value)


def main() raises:
    assert_equal(render(5500), "5500")
    assert_equal(render("valve"), "valve")
    assert_equal(render(Float32(0.5)), "0.5")
