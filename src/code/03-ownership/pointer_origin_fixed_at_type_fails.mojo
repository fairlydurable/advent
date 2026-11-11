# EXPECT-ERROR: a Pointer's origin is part of its type, so it cannot reseat to another owner
# EXPECT-MATCH: cannot implicitly convert
# Claim (3.1): `Pointer(to=primary)` has type `Pointer[String, origin_of(primary)]`;
# assigning a pointer to a different value changes the type.


def main():
    var primary = String("lane-a")
    var spare = String("lane-b")
    var cursor = Pointer(to=primary)
    cursor = Pointer(to=spare)
    print(cursor[])
