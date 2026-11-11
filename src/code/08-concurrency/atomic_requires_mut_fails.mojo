# EXPECT-ERROR: atomic read-modify-write needs mutable access to the Atomic
# EXPECT-MATCH: must be mutable
# Claims:
#   - fetch_add, +=, store, and compare_exchange take `mut self`. Holding an
#     Atomic through a read-only argument only permits load().
from std.atomic import Atomic


def record_hit(hits: Atomic[Int64]):
    hits += 1


def main():
    var hits = Atomic[Int64](0)
    record_hit(hits)
