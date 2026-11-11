# EXPECT-ERROR: a MaybeUninit[String] that nobody resolves
# EXPECT-MATCH: 'slot' abandoned without being explicitly destroyed
# Claim: MaybeUninit never runs T's destructor, so when T has one, the wrapper
# is not Deinitable. You must pick unsafe_assume_init(), unsafe_deinit(), or
# unsafe_forget() on every path.
from std.memory import MaybeUninit


def main():
    var slot = MaybeUninit[String]()
    slot.unsafe_write(String("payload"))
    print(slot.unsafe_assume_init())
