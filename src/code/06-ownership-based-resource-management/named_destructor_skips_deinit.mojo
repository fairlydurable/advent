# Claims:
# - A method taking `deinit self` is a named destructor: calling it consumes
#   the value, and `__deinit__` does not run afterward.
# - Inside a `deinit self` method you can move fields out of `self`.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Session(Movable):
    var token: String
    var implicit_logouts: ArcPointer[Int]

    def __init__(out self, token: String, implicit_logouts: ArcPointer[Int]):
        self.token = token
        self.implicit_logouts = implicit_logouts

    def __deinit__(deinit self):
        self.implicit_logouts[] += 1

    def hand_off_token(deinit self) -> String:
        return self.token^


def main() raises:
    var implicit_logouts = ArcPointer(0)

    _ = Session("tok-31f9", implicit_logouts)
    assert_equal(implicit_logouts[], 1)

    var session = Session("tok-77a2", implicit_logouts)
    var token = session^.hand_off_token()
    assert_equal(token, "tok-77a2")
    assert_equal(implicit_logouts[], 1)
