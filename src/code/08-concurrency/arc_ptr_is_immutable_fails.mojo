# EXPECT-ERROR: ArcPointer.ptr() returns an immutable pointer, so writing through it fails
# EXPECT-MATCH: (immutable|not mutable|cannot be mutated|must be mutable)
# Claims:
#   - ArcPointer.ptr() always returns an immutable pointer, regardless of
#     how the ArcPointer itself is bound, to discourage shared mutation.
from std.memory import ArcPointer


def main():
    var inventory = ArcPointer(320)
    var view = inventory.ptr()
    view[] = 319
