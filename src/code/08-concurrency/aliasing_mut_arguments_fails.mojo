# EXPECT-ERROR: one value passed to two `mut` arguments of the same call
# EXPECT-MATCH: aliasing values passed mutably
# Claims:
#   - Within one thread, the compiler rejects passing one value to two
#     mutable arguments of a single call. This is the exclusivity check.
def transfer(mut source: Int, mut destination: Int, amount: Int):
    source -= amount
    destination += amount


def main():
    var balance = 500
    transfer(balance, balance, 120)
