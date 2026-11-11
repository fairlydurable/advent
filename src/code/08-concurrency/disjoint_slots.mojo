# Claims:
#   - Threads that write disjoint memory do not race, even without atomics.
#   - pthread_join publishes each thread's writes to the joining thread,
#     so plain reads after the join see every result.
#   - Each thread gets its own argument, here a pointer to its own slot.
from threads import ThreadArg, erase, spawn, join
from std.testing import assert_equal


def square_slot(arg: ThreadArg) abi("C") -> ThreadArg:
    var slot = arg.unsafe_bitcast[Int]()
    slot[] = slot[] * slot[]
    return arg


def main() raises:
    var sensor_ids: List[Int] = [3, 5, 8, 13]
    var handles = List[Int]()
    for index in range(len(sensor_ids)):
        handles.append(spawn(square_slot, erase(sensor_ids[index])))
    for handle in handles:
        join(handle)
    assert_equal(sensor_ids, [9, 25, 64, 169])
