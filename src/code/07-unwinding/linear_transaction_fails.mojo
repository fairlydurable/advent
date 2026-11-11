# EXPECT-ERROR: an error path abandons a transaction that must be committed or rolled back
# EXPECT-MATCH: 'txn' abandoned without being explicitly destroyed: finish every transaction
# Claim: a linear transaction type turns "forgot to roll back on error"
# into a compile error at the call that can raise.


struct Transaction(not Deinitable else "finish every transaction with commit() or rollback()"):
    var statements: List[String]

    def __init__(out self):
        self.statements = List[String]()

    def commit(deinit self) -> Int:
        return len(self.statements)

    def rollback(deinit self):
        pass


def validate(statement: String) raises:
    if statement.startswith("DROP"):
        raise Error("refusing destructive statement")


def apply(statements: List[String]) raises -> Int:
    var txn = Transaction()
    for statement in statements:
        validate(statement)
        txn.statements.append(statement)
    return txn^.commit()


def main() raises:
    print(apply(["INSERT INTO audit VALUES (1)"]))
