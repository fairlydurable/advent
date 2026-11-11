# EXPECT-ERROR: a struct left with a hole cannot be destroyed
# EXPECT-MATCH: destroyed out of the middle of a value
# Claim: if a field leaves a local struct value and nothing replaces it, the
# compiler rejects the program, because the remaining value has no valid way
# to be destroyed. This holds even for structs without a custom __deinit__.
@fieldwise_init
struct Link(Movable):
    var primary: String
    var backup: String


def retire(var name: String):
    pass


def main():
    var link = Link("eth0", "wlan0")
    retire(link.primary^)
