# EXPECT-ERROR: an `out` argument left uninitialized on one path
# EXPECT-MATCH: uninitialized value 'retries'
# Claim: a function with an `out` argument must initialize it on every path
# that returns normally.
def parse_retries(text: String, out retries: Int):
    if text == "default":
        retries = 3


def main():
    print(parse_retries("default"))
