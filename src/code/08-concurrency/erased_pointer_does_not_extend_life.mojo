# Claims:
#   - Mojo destroys a value right after its last tracked use (ASAP destruction).
#   - An untracked pointer is not a use: holding one does not keep the
#     value alive. The deinitializer runs before the next line, while the
#     erased pointer still exists.
#   - This sample never dereferences the dangling pointer; it only records
#     the order of events.
from threads import erase
from std.testing import assert_equal


struct JobRecord(Movable):
    var events: Pointer[List[String], MutUntrackedOrigin]

    def __init__(out self, events: Pointer[List[String], MutUntrackedOrigin]):
        self.events = events

    def __deinit__(deinit self):
        self.events[].append("record destroyed")


def main() raises:
    var events = List[String]()
    var event_log = Pointer(to=events).unsafe_origin_cast[MutUntrackedOrigin]()
    var record = JobRecord(event_log)
    var handed_to_thread = erase(record)  # last tracked use of `record`
    events.append("pointer handed off")
    _ = handed_to_thread
    assert_equal(events, ["record destroyed", "pointer handed off"])
