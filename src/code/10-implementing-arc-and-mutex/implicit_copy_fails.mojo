# EXPECT-ERROR: SharedBox is Copyable but not ImplicitlyCopyable, so a plain assignment cannot copy it
# EXPECT-MATCH: implicitly cop
# Claims:
#   - SharedBox conforms to Copyable only. Every refcount increment is a
#     visible .copy() call; `var second = first` while `first` stays in use
#     does not compile. (The stdlib ArcPointer chooses ImplicitlyCopyable.)
from std.atomic import Atomic
from std.memory import MaybeUninit


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Copyable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]):
        self.inner = inner

    def __init__(out self, *, copy: Self):
        _ = copy.inner[].strong.fetch_add(1)
        self.inner = copy.inner


def share(first: SharedBox[Int]):
    var second = first
    _ = second.inner
    _ = first.inner


def main():
    pass
