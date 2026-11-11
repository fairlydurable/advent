# Claims:
# - An abi("C") function cannot capture, so C APIs pass state through a
#   void* context argument instead.
# - pthread_create hands its void* argument, unchanged, to the start
#   routine on the new thread; the routine casts it back to the type the
#   caller pointed it at.
# - The caller must keep the pointed-to value alive until the callback can
#   no longer run; here pthread_join provides that guarantee.

from std.ffi import c_int, external_call
from std.testing import assert_equal

comptime pthread_t = UInt  # pointer-sized on Linux and macOS
comptime Context = MutOpaquePointer[MutUntrackedOrigin]


struct Job:
    var samples: List[Int]
    var total: Int

    def __init__(out self, var samples: List[Int]):
        self.samples = samples^
        self.total = 0


def sum_samples(context: Context) abi("C") -> Optional[Context]:
    ref job = context.unsafe_bitcast[Job]()[]
    for sample in job.samples:
        job.total += sample
    return None


def main() raises:
    var job = Job([512, 1024, 2048, 4096])
    var thread: pthread_t = 0
    var no_attributes: Optional[Context] = None
    var context = (
        Pointer(to=job).unsafe_bitcast[NoneType]().unsafe_origin_cast[
            MutUntrackedOrigin
        ]()
    )
    # int pthread_create(pthread_t *thread, const pthread_attr_t *attr,
    #                    void *(*start)(void *), void *arg);
    var created = external_call["pthread_create", c_int](
        Pointer(to=thread), no_attributes, sum_samples, context
    )
    assert_equal(created, 0)
    var no_result: Optional[Pointer[Optional[Context], MutUntrackedOrigin]] = None
    # int pthread_join(pthread_t thread, void **result);
    assert_equal(external_call["pthread_join", c_int](thread, no_result), 0)
    assert_equal(job.total, 7680)
