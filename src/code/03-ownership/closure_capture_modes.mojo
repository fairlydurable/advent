# Claims (3.7):
# - A capture with no convention reads the captured value at call time
#   (it captures a reference, not a snapshot).
# - `var` captures a copy when the closure forms.
# - `mut` captures a mutable reference.
from std.testing import assert_equal


def main() raises:
    var status = String("idle")

    def current() {status} -> String:
        return status

    def snapshot() {var status} -> String:
        return status

    def advance(next: String) {mut status}:
        status = next

    advance("running")
    assert_equal(current(), "running")
    assert_equal(snapshot(), "idle")
    assert_equal(status, "running")
