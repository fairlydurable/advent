# Claim: MaybeUninit.zeroed() fills the bytes with zero. For Int that is a
# valid value; for types like String it is not.
# Claim: for trivially deinitializable T, write() may overwrite freely.
from std.memory import MaybeUninit
from std.testing import assert_equal


def main() raises:
    var hits = MaybeUninit[Int].zeroed()
    assert_equal(hits.unsafe_assume_init(), 0)
    hits.write(5500)
    hits.write(5600)
    assert_equal(hits.unsafe_assume_init(), 5600)
