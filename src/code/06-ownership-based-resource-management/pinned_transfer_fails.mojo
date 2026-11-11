# EXPECT-ERROR: transferring a non-Movable value into a new binding needs relocation
# EXPECT-MATCH: doesn't conform to 'Movable'
# Claim: `var dest = source^` relocates, so it requires Movable.


struct SpinLockSlot(not Movable):
    var owner_id: Int

    def __init__(out self, owner_id: Int):
        self.owner_id = owner_id


def main():
    var slot = SpinLockSlot(7)
    var relocated = slot^
    print(relocated.owner_id)
