# EXPECT-ERROR: two elements of one List passed to two mut arguments
# EXPECT-MATCH: temps\["element"\]
# Claim (3.2): every element of a List shares one interior origin, so the checker
# cannot tell `temps[0]` from `temps[1]` and rejects the call.


def main():
    var temps: List[Int] = [12, 18, 25]
    swap(temps[0], temps[1])
    print(temps)
