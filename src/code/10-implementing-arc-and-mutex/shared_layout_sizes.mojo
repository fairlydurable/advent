# Claims:
#   - A SharedBox is one pointer wide; the count and payload live on the heap.
#   - MaybeUninit[T] has exactly the size of T: it adds no flag.
#   - The heap block is count plus payload, padded to the larger alignment:
#     a one-byte payload still occupies 16 bytes.
#   - Optional[Pointer] reuses the null address as None, so it stays 8 bytes.
#     A struct that wraps a Pointer does not inherit that niche: Optional of
#     this SharedBox needs 16 bytes, while the stdlib ArcPointer opts into
#     the niche through a non-public conformance and stays at 8.
from std.atomic import Atomic
from std.memory import ArcPointer, MaybeUninit
from std.sys import align_of, size_of
from std.testing import assert_equal


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Movable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]


def main() raises:
    assert_equal(size_of[SharedBox[String]](), size_of[Int]())
    assert_equal(size_of[MaybeUninit[String]](), size_of[String]())
    assert_equal(size_of[SharedInner[Int64]](), 16)
    assert_equal(size_of[SharedInner[UInt8]](), 16)
    assert_equal(align_of[SharedInner[UInt8]](), 8)

    assert_equal(size_of[Optional[Pointer[Int, MutUntrackedOrigin]]](), 8)
    assert_equal(size_of[Optional[SharedBox[String]]](), 16)
    assert_equal(size_of[Optional[ArcPointer[String]]](), 8)
