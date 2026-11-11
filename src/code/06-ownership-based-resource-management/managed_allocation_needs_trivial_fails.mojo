# EXPECT-ERROR: managed storage would skip element destructors, so it refuses types that have them
# EXPECT-MATCH: invalid call to 'into_managed': violated constraint
# Claim: `into_managed()` requires a trivially deinitializable element type,
# because ManagedAllocation never runs element destructors.
from std.memory import alloc, Layout


def main():
    var names = alloc(Layout[String](length=2)).into_managed()
    print(len(names))
