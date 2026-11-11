# Claim (3.1): a `ref` binding to a function result materializes the temporary
# and keeps it alive (and mutable) for every use of the binding.
from std.testing import assert_equal


def pallet_label() -> String:
    return "pallet"


def main() raises:
    ref label = pallet_label()
    label += "-7"
    assert_equal(label, "pallet-7")
