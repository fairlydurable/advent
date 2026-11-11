# EXPECT-ERROR: an init_with closure cannot capture a move-only payload by value
# EXPECT-MATCH: cannot capture value by copy
# Claims:
#   - Building a non-Movable block in place needs unsafe_write(init_with=...).
#   - That closure cannot take ownership of a payload that is only Movable,
#     which is why SharedBox builds the block first and writes the payload
#     into its MaybeUninit field second.
from std.atomic import Atomic
from std.memory import alloc, Layout, MaybeUninit


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self, var value: Self.T):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T](value^)

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


def make_block[T: Movable](var value: T) -> Pointer[SharedInner[T], MutUntrackedOrigin]:
    var block = alloc(Layout[SharedInner[T]].single()).unsafe_leak()
    block.unsafe_write(init_with=lambda () {var value} -> SharedInner[T]: SharedInner[T](value^))
    return block


def main():
    _ = make_block(String("route table"))
