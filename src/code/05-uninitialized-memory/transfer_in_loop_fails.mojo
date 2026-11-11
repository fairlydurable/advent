# EXPECT-ERROR: transferring a value inside a loop that can come around again
# EXPECT-MATCH: uninitialized value 'batch'
# Claim: without a `break` after the transfer, the next iteration could
# transfer an empty binding, so the compiler rejects it.
def ship(var batch: List[Int]):
    pass


def main():
    var batch: List[Int] = [512, 1024]
    for attempt in range(3):
        if attempt == 1:
            ship(batch^)
