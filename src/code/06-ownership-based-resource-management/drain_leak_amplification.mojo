# Claims:
# - A guard that borrows a container must leave the container sound even if
#   the guard's destructor never runs.
# - Drain sets the queue's length to zero up front ("leak amplification").
#   Forgetting the Drain then leaks the remaining jobs instead of letting
#   the queue destroy them a second time.
# - When the Drain dies normally, its destructor destroys the jobs nobody
#   took.
from std.memory import (
    alloc,
    dealloc,
    Layout,
    Allocation,
    ArcPointer,
    forget_deinit,
    unsafe_destroy_n,
)
from std.testing import assert_equal


struct Job(Movable):
    var id: Int
    var retired: ArcPointer[Int]

    def __init__(out self, id: Int, retired: ArcPointer[Int]):
        self.id = id
        self.retired = retired

    def __deinit__(deinit self):
        self.retired[] += 1


struct JobQueue(Movable):
    var storage: Allocation[Job]
    var length: Int

    def __init__(out self, capacity: Int):
        self.storage = alloc(Layout[Job](length=capacity))
        self.length = 0

    def push(mut self, var job: Job):
        debug_assert(self.length < len(self.storage), "queue is full")
        self.storage.unsafe_ptr().unsafe_offset(self.length).unsafe_write(job^)
        self.length += 1

    def drain(mut self) -> Drain[origin_of(self)]:
        return Drain(self)

    def __deinit__(deinit self):
        unsafe_destroy_n(self.storage.unsafe_ptr(), self.length)
        dealloc(self.storage^)


struct Drain[origin: MutOrigin](Movable):
    var queue: Pointer[JobQueue, Self.origin]
    var next_index: Int
    var end: Int

    def __init__(out self, ref[Self.origin] queue: JobQueue):
        self.end = queue.length
        # Leak amplification: from here on, the queue owns no elements.
        queue.length = 0
        self.next_index = 0
        self.queue = Pointer(to=queue)

    def next(mut self) -> Optional[Job]:
        if self.next_index == self.end:
            return None
        var slot = self.queue[].storage.unsafe_ptr().unsafe_offset(
            self.next_index
        )
        self.next_index += 1
        return slot.unsafe_take_pointee()

    def __deinit__(deinit self):
        var base = self.queue[].storage.unsafe_ptr()
        unsafe_destroy_n(
            base.unsafe_offset(self.next_index), self.end - self.next_index
        )


def main() raises:
    var retired = ArcPointer(0)
    var queue = JobQueue(capacity=4)
    for id in range(4):
        queue.push(Job(1000 + id, retired))

    var drain = queue.drain()
    var first = drain.next()
    assert_equal(first.value().id, 1000)
    _ = drain^
    assert_equal(retired[], 3)
    _ = first^
    assert_equal(retired[], 4)

    for id in range(4):
        queue.push(Job(2000 + id, retired))
    var abandoned = queue.drain()
    forget_deinit(abandoned^)
    assert_equal(queue.length, 0)
    _ = queue^
    # The four forgotten jobs leaked: no destructor ran, and none ran twice.
    assert_equal(retired[], 4)
