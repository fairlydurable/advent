# EXPECT-ERROR: an UnsafeUnion member with a destructor
# EXPECT-MATCH: trivial destructors
# Claim: UnsafeUnion accepts only trivially copyable, movable, and
# deinitializable members, because it never knows which member to destroy.
from std.ffi import UnsafeUnion


def main():
    var slot = UnsafeUnion[Int64, String](Int64(1))
    print(slot.unsafe_get[Int64]())
