# Claim: memory from alloc() starts uninitialized; unsafe_write() moves a
# value in without destroying whatever bits were there.
# Claim: assignment through a pointer (ptr[] = value) treats the slot as
# initialized and destroys the old value first.
# Claim: unsafe_take_pointee() moves the value out without running its
# destructor; unsafe_deinit_pointee() runs the destructor in place.
# Claim: dealloc() frees storage only. It never runs element destructors.
from std.memory import alloc, dealloc, ArcPointer, Layout
from std.testing import assert_equal


# The log lives behind an ArcPointer, so a Tracer carries no origin and can
# sit in heap storage next to other Tracers.
struct Tracer(Movable):
    var label: String
    var log: ArcPointer[List[String]]

    def __init__(out self, label: String, log: ArcPointer[List[String]]):
        self.label = label
        self.log = log

    def __deinit__(deinit self):
        self.log[].append("drop " + self.label)


def main() raises:
    var events = ArcPointer(List[String]())
    var allocation = alloc(Layout[Tracer](length=2))
    var slots = allocation.unsafe_ptr()
    slots.unsafe_write(Tracer("north", events))
    slots.unsafe_offset(1).unsafe_write(Tracer("south", events))
    events[].append("written")

    slots[] = Tracer("east", events)  # destroys "north"
    events[].append("assigned")

    var taken = slots.unsafe_offset(1).unsafe_take_pointee()
    events[].append("took " + taken.label)

    slots.unsafe_deinit_pointee()  # destroys "east" in place
    dealloc(allocation^)
    events[].append("freed")
    assert_equal(
        events[],
        [
            "written",
            "drop north",
            "assigned",
            "drop south",
            "took south",
            "drop east",
            "freed",
        ],
    )
