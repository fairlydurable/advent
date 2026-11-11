# Claims (3.5):
# - `Pointer(to=city)` infers both the pointee type and `origin_of(city)`.
# - A `_` in a parameter list accepts any origin and binds it at the call.
from std.testing import assert_equal


def byte_count(cursor: Pointer[String, _]) -> Int:
    return cursor[].byte_length()


def main() raises:
    var city = String("Quito")
    var spelled: Pointer[String, origin_of(city)] = Pointer(to=city)
    var inferred = Pointer(to=city)
    assert_equal(byte_count(spelled), 5)
    assert_equal(byte_count(inferred), 5)
