# Claims:
#   - The fix for early destruction: give the shared value a tracked use
#     after the last join. `deinit(value^)` is a builtin that exists for
#     exactly this: it pins the end of the value's life to that line.
#   - With the value pinned, the thread finishes its work before the
#     deinitializer runs.
from threads import ThreadArg, erase, spawn, join
from std.testing import assert_equal


struct JobRecord(Movable):
    var steps_done: Int
    var events: Pointer[List[String], MutUntrackedOrigin]

    def __init__(out self, events: Pointer[List[String], MutUntrackedOrigin]):
        self.steps_done = 0
        self.events = events

    def __deinit__(deinit self):
        self.events[].append(String("record destroyed after ", self.steps_done, " steps"))


def run_job(arg: ThreadArg) abi("C") -> ThreadArg:
    var record = arg.unsafe_bitcast[JobRecord]()
    for _ in range(3):
        record[].steps_done += 1
    return arg


def main() raises:
    var events = List[String]()
    var event_log = Pointer(to=events).unsafe_origin_cast[MutUntrackedOrigin]()
    var record = JobRecord(event_log)
    var worker = spawn(run_job, erase(record))
    join(worker)
    events.append("worker joined")
    deinit(record^)  # the record's life ends here, not at `erase`
    assert_equal(events, ["worker joined", "record destroyed after 3 steps"])
