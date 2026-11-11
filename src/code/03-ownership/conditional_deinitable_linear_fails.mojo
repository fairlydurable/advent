# EXPECT-ERROR: the program abandons a Cell that holds a linear Receipt
# EXPECT-MATCH: does not conditionally conform to 'Deinitable'
# Claim (3.10): the conditional conformance carries the element's linearity to
# the container.
from std.memory import alloc, dealloc, Layout, Allocation


struct Cell[T: Movable](Deinitable where conforms_to(T, Deinitable), Movable):
    var storage: Allocation[Self.T]

    def __init__(out self, var value: Self.T):
        self.storage = alloc(Layout[Self.T].single())
        self.storage.unsafe_ptr().unsafe_write(value^)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        self.storage.unsafe_ptr().unsafe_deinit_pointee()
        dealloc(self.storage^)


struct Receipt(not Deinitable, Movable):
    var amount: Int

    def __init__(out self, amount: Int):
        self.amount = amount

    def file(deinit self) -> Int:
        return self.amount


def main():
    var receipt_cell = Cell(Receipt(120))
    print("never filed")
