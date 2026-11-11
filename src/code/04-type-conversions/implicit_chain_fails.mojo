# EXPECT-ERROR: two implicit conversions in a row
# EXPECT-MATCH: cannot be converted from 'IntLiteral\[5\]' to 'Millis'
# Claim: implicit conversions never chain. Int to Seconds and Seconds to
# Millis each work, but the compiler will not go Int to Seconds to Millis.
struct Seconds(ImplicitlyCopyable):
    var count: Int

    @implicit
    def __init__(out self, count: Int):
        self.count = count


struct Millis(ImplicitlyCopyable):
    var count: Int

    @implicit
    def __init__(out self, seconds: Seconds):
        self.count = seconds.count * 1000


def timeout_budget(duration: Millis) -> Int:
    return duration.count


def main():
    print(timeout_budget(5))
