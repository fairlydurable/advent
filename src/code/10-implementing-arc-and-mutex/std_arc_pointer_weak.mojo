# Claims:
#   - The stdlib ArcPointer adds weak references on top of the design in
#     this chapter: a second count, and a block that outlives the payload.
#   - A weak pointer does not keep the payload alive. try_upgrade() returns
#     a new strong pointer while one exists, and None after the last strong
#     pointer dies, even though the weak pointer itself is still live.
#   - weak_count() excludes the one implicit weak reference that all strong
#     pointers share.
from std.memory import ArcPointer
from std.testing import assert_equal, assert_false


def main() raises:
    var device_names: List[String] = ["gpu0", "gpu1"]
    var registry = ArcPointer(device_names^)
    var watcher = ArcPointer[List[String]].WeakPointer(downgrade=registry)
    assert_equal(registry.count(), 1)
    assert_equal(registry.weak_count(), 1)

    var upgraded = watcher.try_upgrade()
    assert_equal(upgraded.value().count(), 2)  # last use of `upgraded`
    assert_equal(registry.count(), 1)

    deinit(registry^)  # the payload dies here
    assert_equal(watcher.strong_count(), 0)
    assert_false(Bool(watcher.try_upgrade()))
