# Claim: a `TrivialRegisterPassable` struct travels in registers, copies
# implicitly with a bitwise copy, and still has an address when bound to a
# `var`, so `Pointer(to=)` works on it.
# Claim: a `RegisterPassable` (non-trivial) struct may define `__deinit__`,
# and Mojo runs it after the value's last use.
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Rgba(TrivialRegisterPassable):
    var packed: UInt32


@fieldwise_init
struct Share(RegisterPassable):
    var owner: ArcPointer[String]


def main() raises:
    var fill = Rgba(0xFF336699)
    var stroke = fill  # Implicit copy.
    stroke.packed = 0xFF000000
    assert_equal(fill.packed, 0xFF336699)
    var fill_ref = Pointer(to=fill)
    assert_equal(fill_ref[].packed, 0xFF336699)

    var tenant = ArcPointer(String("acme-prod"))
    var lease = Share(tenant.copy())
    assert_equal(tenant.count(), 2)
    _ = lease^
    assert_equal(tenant.count(), 1)
