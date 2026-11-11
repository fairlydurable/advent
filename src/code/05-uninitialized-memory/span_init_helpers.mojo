# Claim: a Span over MaybeUninit elements initializes in bulk with
# unsafe_init_with() and unsafe_init_copy_from(), each returning a span typed
# as the initialized element type.
# Claim: an Array of MaybeUninit[String] is not Deinitable, so you tear it
# down explicitly: destroy the elements, then forget the wrappers.
from std.memory import MaybeUninit
from std.testing import assert_equal


def forget_slot(var slot: MaybeUninit[String]):
    slot^.unsafe_forget()  # the String inside is already destroyed


def main() raises:
    var storage = Array[MaybeUninit[Int], 5]()
    var squares = Span(storage).unsafe_init_with(
        lambda (index: Int) -> Int: index * index
    )
    assert_equal(squares[4], 16)

    var source: Array[String, 2] = ["inlet", "outlet"]
    var names = Array[MaybeUninit[String], 2]()
    var copied = Span(names).unsafe_init_copy_from(source)
    var second = copied[1]
    copied.unsafe_deinit_elements()
    names^.deinit_with(forget_slot)  # resolve before any assert can raise
    assert_equal(second, "outlet")
