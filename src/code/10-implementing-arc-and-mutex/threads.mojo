# Shared helper for the concurrency samples: POSIX threads through FFI.
# Claims:
#   - The standard library has no thread-spawning API, so these samples
#     call pthread_create and pthread_join from libc.
#   - A thread entry point is a thin, non-capturing C-ABI function. All state
#     a thread sees arrives through one type-erased pointer argument.
#   - `erase` is the single point where a tracked reference becomes an
#     untracked pointer. After it, origins no longer protect the value.
from std.ffi import external_call, c_int
from std.os import abort
from std.testing import assert_equal

comptime ThreadArg = MutOpaquePointer[MutUntrackedOrigin]
comptime ThreadEntry = def(ThreadArg) thin abi("C") -> ThreadArg


def erase[T: AnyType, origin: MutOrigin, //](ref[origin] value: T) -> ThreadArg:
    """Turns a reference into an untracked `void*`. The caller keeps `value`
    alive and unmoved until every thread that received the pointer has joined.
    """
    return (
        Pointer(to=value)
        .unsafe_origin_cast[MutUntrackedOrigin]()
        .unsafe_bitcast[NoneType]()
    )


def spawn(entry: ThreadEntry, arg: ThreadArg) -> Int:
    """Starts a thread running `entry(arg)` and returns its pthread handle."""
    var handle = 0  # pthread_t is pointer-sized on 64-bit macOS and Linux
    var no_attributes: Optional[ThreadArg] = None
    var status = external_call["pthread_create", c_int](
        Pointer(to=handle), no_attributes, entry, arg
    )
    if status != 0:
        abort("pthread_create failed")
    return handle


def join(handle: Int):
    """Blocks until the thread finishes. Joining publishes everything the
    thread wrote to the joining thread."""
    var discarded_result: Optional[ThreadArg] = None
    var status = external_call["pthread_join", c_int](
        handle, Pointer(to=discarded_result)
    )
    if status != 0:
        abort("pthread_join failed")


def run_threads(entry: ThreadEntry, arg: ThreadArg, thread_count: Int):
    """Runs `entry(arg)` on `thread_count` threads and joins them all."""
    var handles = List[Int](capacity=thread_count)
    for _ in range(thread_count):
        handles.append(spawn(entry, arg))
    for handle in handles:
        join(handle)


def record_slot(arg: ThreadArg) abi("C") -> ThreadArg:
    arg.unsafe_bitcast[Int]()[] = 7
    return arg


def main() raises:
    # Self-test: one thread writes a slot the main thread owns.
    var slot = 0
    join(spawn(record_slot, erase(slot)))
    assert_equal(slot, 7)
