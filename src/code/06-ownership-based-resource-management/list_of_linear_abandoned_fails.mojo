# EXPECT-ERROR: a List of linear elements cannot die implicitly
# EXPECT-MATCH: Use `deinit_with\(\)` to explicitly destroy
# Claim: List's conditional conformance carries its own guidance message.


struct Ticket(not Deinitable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def resolve(deinit self):
        pass


def main():
    var backlog = List[Ticket]()
    backlog.append(Ticket(301))
    print(len(backlog))
