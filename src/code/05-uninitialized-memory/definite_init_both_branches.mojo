# Claim: a binding may be declared without a value and initialized later, as
# long as every path initializes it before the first read.
# Claim: deferred initialization works for owning types such as String too.
from std.sys import argv
from std.testing import assert_equal


def main() raises:
    var interactive = len(argv()) > 0  # known only at run time
    var timeout_ms: Int
    if interactive:
        timeout_ms = 5000
    else:
        timeout_ms = 250
    assert_equal(timeout_ms, 5000)

    var mode: String
    mode = "streaming" if interactive else "batch"
    assert_equal(mode, "streaming")
