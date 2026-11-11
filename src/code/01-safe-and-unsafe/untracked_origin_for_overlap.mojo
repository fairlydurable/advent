# Claim: two element references into one List can't both go to `mut`
# arguments of one call; the safe answer is a method that does the work
# inside the container (`swap_elements`).
# Claim: inside a container's own implementation, casting the element
# pointer to `MutUntrackedOrigin` steps outside exclusivity checking; the
# code then owns the proof that the accesses don't conflict.
from std.testing import assert_equal


def rotate_left_by_one(mut queue: List[String]):
    if len(queue) < 2:
        return
    var data = queue.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    # Each step swaps two distinct, initialized slots.
    for index in range(len(queue) - 1):
        data.unsafe_offset(index).swap_pointees(data.unsafe_offset(index + 1))


def main() raises:
    var queue: List[String] = ["ingest", "transform", "publish"]
    queue.swap_elements(0, 2)
    assert_equal(queue[0], "publish")
    assert_equal(queue[2], "ingest")

    rotate_left_by_one(queue)
    assert_equal(queue[0], "transform")
    assert_equal(queue[1], "ingest")
    assert_equal(queue[2], "publish")
