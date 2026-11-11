# Claims (3.10):
# - A container that owns a `T` through raw storage states that ownership with
#   `Deinitable where conforms_to(T, Deinitable)`.
# - With a Deinitable `T`, the container destroys its element automatically.
# - With a linear `T`, the container becomes linear too and needs a consuming
#   method such as `into_inner`.
from std.memory import alloc, dealloc, Layout, Allocation
from std.testing import assert_equal


struct Cell[T: Movable](Deinitable where conforms_to(T, Deinitable), Movable):
    var storage: Allocation[Self.T]

    def __init__(out self, var value: Self.T):
        self.storage = alloc(Layout[Self.T].single())
        self.storage.unsafe_ptr().unsafe_write(value^)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        self.storage.unsafe_ptr().unsafe_deinit_pointee()
        dealloc(self.storage^)

    def into_inner(deinit self) -> Self.T:
        var value = self.storage.unsafe_ptr().unsafe_take_pointee()
        dealloc(self.storage^)
        return value^


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


struct Receipt(not Deinitable, Movable):
    var amount: Int

    def __init__(out self, amount: Int):
        self.amount = amount

    def file(deinit self) -> Int:
        return self.amount


def main() raises:
    var log = List[String]()
    _ = Cell(Probe("boxed", log))
    log.append("cell gone")
    assert_equal(log, ["deinit boxed", "cell gone"])

    var receipt_cell = Cell(Receipt(120))
    assert_equal(receipt_cell^.into_inner().file(), 120)
