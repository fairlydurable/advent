# EXPECT-ERROR: a struct that declares no constructor has no way to make a value from scratch
# EXPECT-MATCH: invalid initialization
# Claim: a struct with no `__init__` exists only as a type. Mojo
# synthesizes a move constructor for it, which needs an existing value, so
# nothing can create the first one.
struct SessionToken:
    pass


def main():
    var token = SessionToken()
