# Claims:
#   - A `{mut name}` capture is a reference to the enclosing binding, not a
#     copy: calls to the closure change the original.
#   - A `{var name}` capture is an owned snapshot taken at the moment you create the closure:
#     created: later changes to the original do not reach it.
from std.testing import assert_equal


def main() raises:
    var total_bytes = 0
    var budget = 4096

    def account(packet_bytes: Int) {mut total_bytes}:
        total_bytes += packet_bytes

    def remaining(packet_bytes: Int) {var budget} -> Int:
        return budget - packet_bytes

    account(1500)
    account(576)
    budget = 1024
    assert_equal(total_bytes, 2076)
    assert_equal(remaining(1500), 2596)  # computed from the 4096 snapshot
    assert_equal(budget, 1024)
