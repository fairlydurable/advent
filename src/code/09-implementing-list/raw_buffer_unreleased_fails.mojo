# EXPECT-ERROR: a RawBuffer that goes out of scope without release() is a compile error
# EXPECT-MATCH: abandoned without being explicitly destroyed: call release
# Claim: making the allocation owner linear moves "did someone free this?"
# from code review into the type checker.

from std.memory import Allocation, Layout, alloc, dealloc


struct RawBuffer[T: AnyType](
    Movable, not Deinitable else "call release() to free a RawBuffer"
):
    var _storage: Allocation[Self.T]

    def __init__(out self, capacity: Int):
        self._storage = alloc(Layout[Self.T](length=capacity))

    def release(deinit self):
        dealloc(self._storage^)


def checksum(packet_size: Int) -> Int:
    var scratch = RawBuffer[UInt8](packet_size)
    return packet_size % 251  # returns without releasing `scratch`


def main():
    print(checksum(1500))
