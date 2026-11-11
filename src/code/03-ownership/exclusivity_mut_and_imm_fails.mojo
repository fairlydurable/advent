# EXPECT-ERROR: one value passed both mutably and immutably to the same call
# EXPECT-MATCH: aliasing values passed mutably to 'journal'.*immutably to 'entry'
# Claim (3.2): a `mut` argument may not alias any other argument of the same call.


def append_twice(mut journal: String, entry: String):
    journal += entry
    journal += entry


def main():
    var journal = String("boot;")
    append_twice(journal, journal)
    print(journal)
