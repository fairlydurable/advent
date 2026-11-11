# Claim: Allocation.storage() views fresh heap memory as Span[MaybeUninit[T]],
# so initialization goes through the same span helpers.
# Claim: unsafe_write(init_with=) builds a value in place, which works for a
# type that is not Movable.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal


@fieldwise_init
struct Listener(not Movable):
    var port: Int


def main() raises:
    var allocation = alloc(Layout[String](length=3))
    var stages = allocation.storage().unsafe_init_with(
        lambda (index: Int) -> String: String("stage-", index)
    )
    var last_stage = stages[2]
    stages.unsafe_deinit_elements()
    dealloc(allocation^)
    assert_equal(last_stage, "stage-2")

    var slot = alloc(Layout[Listener].single())
    var listener = slot.unsafe_ptr()
    listener.unsafe_write(init_with=lambda () -> Listener: Listener(8080))
    var port = listener[].port
    listener.unsafe_deinit_pointee()
    dealloc(slot^)
    assert_equal(port, 8080)
