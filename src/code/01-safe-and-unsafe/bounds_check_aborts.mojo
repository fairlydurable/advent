# EXPECT-EXIT: nonzero
# Claim: `List` indexing checks bounds on CPU at the default assertion
# level, and an out-of-range index aborts the program instead of reading
# past the end. Building with `-D ASSERT=none` removes this check.
def main():
    var readings: List[Int] = [12, 15, 19]
    var index = len(readings)
    print(readings[index])
