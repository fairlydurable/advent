# Claims:
# - Handling the error edge with `rollback()` in an `except` block makes the
#   linear transaction legal on every path.
# - The caller observes the rollback, never a half-applied transaction.
from std.memory import ArcPointer
from std.testing import assert_equal, assert_raises


struct Transaction(not Deinitable else "finish every transaction with commit() or rollback()"):
    var statements: List[String]
    var outcomes: ArcPointer[List[String]]

    def __init__(out self, outcomes: ArcPointer[List[String]]):
        self.statements = List[String]()
        self.outcomes = outcomes

    def commit(deinit self) -> Int:
        self.outcomes[].append(String("commit ", len(self.statements)))
        return len(self.statements)

    def rollback(deinit self):
        self.outcomes[].append(String("rollback ", len(self.statements)))


def validate(statement: String) raises:
    if statement.startswith("DROP"):
        raise Error("refusing destructive statement")


def apply(
    statements: List[String], outcomes: ArcPointer[List[String]]
) raises -> Int:
    var txn = Transaction(outcomes)
    for statement in statements:
        try:
            validate(statement)
        except e:
            txn^.rollback()
            raise e^
        txn.statements.append(statement)
    return txn^.commit()


def main() raises:
    var outcomes = ArcPointer(List[String]())
    assert_equal(apply(["INSERT 1", "INSERT 2"], outcomes), 2)
    with assert_raises(contains="destructive"):
        _ = apply(["INSERT 3", "DROP TABLE audit"], outcomes)
    assert_equal(outcomes[], ["commit 2", "rollback 1"])
