# EXPECT-ERROR: an origin names a temporary that dies before the name is used
# EXPECT-MATCH: must outlive the expression naming it
# Claim (3.3): origins name storage that lives long enough. The result of a call
# is a temporary, so its origin cannot appear in a binding's type.


def load_route() -> String:
    return "A7"


def main():
    var route: Pointer[String, origin_of(load_route())]
