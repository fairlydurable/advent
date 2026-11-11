# Claims:
#   - fence() moves the ordering off the atomic operation: a RELEASE fence
#     followed by a RELAXED store publishes like a RELEASE store, and a
#     RELAXED load followed by an ACQUIRE fence acquires like an ACQUIRE load.
#   - The pattern pays for the fence once, after a loop of relaxed polls,
#     instead of on every poll.
from threads import ThreadArg, erase, spawn, join
from std.atomic import Atomic, Ordering, fence
from std.testing import assert_equal


struct Handoff(Movable):
    var ready: Atomic[UInt8]
    var frame_count: Int
    var seen_frames: Int

    def __init__(out self):
        self.ready = Atomic[UInt8](0)
        self.frame_count = 0
        self.seen_frames = 0


def render(arg: ThreadArg) abi("C") -> ThreadArg:
    var handoff = arg.unsafe_bitcast[Handoff]()
    handoff[].frame_count = 240
    fence[ordering=Ordering.RELEASE]()
    handoff[].ready.store[ordering=Ordering.RELAXED](1)
    return arg


def present(arg: ThreadArg) abi("C") -> ThreadArg:
    var handoff = arg.unsafe_bitcast[Handoff]()
    while handoff[].ready.load[ordering=Ordering.RELAXED]() == 0:
        pass
    fence[ordering=Ordering.ACQUIRE]()
    handoff[].seen_frames = handoff[].frame_count
    return arg


def main() raises:
    var handoff = Handoff()
    var presenter = spawn(present, erase(handoff))
    var renderer = spawn(render, erase(handoff))
    join(renderer)
    join(presenter)
    assert_equal(handoff.seen_frames, 240)
