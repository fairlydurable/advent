# EXPECT-ERROR: a pointer to a local can't convert to a caller-chosen origin
# EXPECT-MATCH: cannot implicitly convert 'Pointer\[Int, origin_of\(local_reading\)\]'
# Claim: a function can't return a pointer to its own local under an origin
# the caller picked; the local's origin doesn't convert to it.
def latest_reading[origin: MutOrigin]() -> Pointer[Int, origin]:
    var local_reading = 512
    return Pointer(to=local_reading)


def main():
    pass
