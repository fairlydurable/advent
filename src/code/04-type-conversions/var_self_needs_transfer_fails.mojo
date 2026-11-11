# EXPECT-ERROR: a `var self` method on a non-copyable binding without `^`
# EXPECT-MATCH: cannot be implicitly copied
# Claim: a `var self` method takes ownership. For a type that is not
# ImplicitlyCopyable, the call site must write `binding^.method()`.
struct Session(Movable):
    var token: String

    def __init__(out self, token: String):
        self.token = token

    def close(var self) -> String:
        return self.token


def main():
    var session = Session("a91f")
    print(session.close())
