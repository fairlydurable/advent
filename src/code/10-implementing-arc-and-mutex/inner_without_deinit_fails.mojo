# EXPECT-ERROR: a MaybeUninit field of a non-trivial payload must be released explicitly
# EXPECT-MATCH: non-.Deinitable
# Claims:
#   - MaybeUninit[String] is not Deinitable: it never knows whether it holds
#     a live String, so it refuses to guess.
#   - A struct is Deinitable by default, and a compiler-generated
#     deinitializer cannot destroy that field, so the declaration itself is
#     rejected. Writing a __deinit__ that consumes the field (for example
#     with unsafe_forget()) settles the question.
from std.atomic import Atomic
from std.memory import MaybeUninit


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()


def main():
    var block = SharedInner[String]()
    _ = block.strong.load()
