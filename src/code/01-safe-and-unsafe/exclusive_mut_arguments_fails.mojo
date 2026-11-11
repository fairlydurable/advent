# EXPECT-ERROR: one value passed to two mut arguments of the same call
# EXPECT-MATCH: aliasing values passed mutably
# Claim: a call can't receive the same value through two `mut` arguments.
def settle(mut payer: Int, mut payee: Int, amount: Int):
    payer -= amount
    payee += amount


def main():
    var balance_cents = 10_000
    settle(balance_cents, balance_cents, 2_500)
