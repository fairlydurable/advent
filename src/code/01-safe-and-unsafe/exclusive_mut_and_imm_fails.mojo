# EXPECT-ERROR: one String passed to a mut argument and an imm argument of the same call
# EXPECT-MATCH: passed immutably
# Claim: a `mut` argument excludes every other reference to the same value
# in that call, including an immutable one.
def append_twice(mut journal: String, imm entry: String):
    journal += entry
    journal += entry


def main():
    var journal = String("boot;")
    append_twice(journal, journal)
