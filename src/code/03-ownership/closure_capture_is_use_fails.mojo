# EXPECT-ERROR: a closure that captured `journal` runs after `journal` moved away
# EXPECT-MATCH: use of uninitialized value 'journal'
# Claim (3.7): calling a closure counts as a use of everything it captured by
# reference.


def main():
    var journal = String("start")

    def record(entry: String) {mut journal}:
        journal += entry

    record(";one")
    var archived = journal^
    record(";two")
    print(archived)
