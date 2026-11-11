# Claim: inside `comptime if conforms_to(T, Writable)`, downcast[T, Writable]
# names T viewed as a Writable type, and rebind turns the reference into one
# of that type, so trait methods become callable on a T: AnyType value.
from std.builtin.rebind import downcast
from std.testing import assert_equal


def describe[T: AnyType](ref value: T) -> String:
    comptime if conforms_to(T, Writable):
        return String(rebind[downcast[T, Writable]](value))
    else:
        return "<opaque>"


struct RawFrame:
    var length: Int

    def __init__(out self):
        self.length = 1500


def main() raises:
    assert_equal(describe(5500), "5500")
    assert_equal(describe(RawFrame()), "<opaque>")
