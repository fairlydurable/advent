# Claims:
#   - The exclusivity check applies to the arguments of a call. Two mutable
#     `Pointer`s to the same value can coexist and both write through it.
#   - So "I hold a mutable pointer" never implies "nobody else can write":
#     sharing state across threads rests on this same fact.
from std.atomic import Atomic
from std.testing import assert_equal


def main() raises:
    var page_views = Atomic[Int64](0)
    var from_frontend = Pointer(to=page_views)
    var from_crawler = Pointer(to=page_views)
    from_frontend[] += 1
    from_crawler[] += 1
    assert_equal(page_views.load(), 2)
