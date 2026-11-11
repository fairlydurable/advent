# EXPECT-ERROR: a trivial register-passable type can't declare a destructor
# EXPECT-MATCH: trivial types must not declare
# Claim: `TrivialRegisterPassable` promises no observable destruction, so
# the compiler rejects a `__deinit__` on it.
@fieldwise_init
struct Rgba(TrivialRegisterPassable):
    var packed: UInt32

    def __deinit__(deinit self):
        print("released color")


def main():
    var fill = Rgba(0xFF336699)
