# Dropping.
# Claims:
#   - The payload's deinitializer runs exactly once, when the last copy
#     dies, no matter which copy that is.
#   - The decrement uses RELEASE; the last owner adds an ACQUIRE fence
#     before it destroys the payload (section 10.1.4 explains why).
#   - The order of destruction is payload, then block, then storage.
from std.atomic import Atomic, Ordering, fence
from std.memory import alloc, dealloc, Layout, MaybeUninit
from std.memory.alloc import ThinAllocation
from std.testing import assert_equal


struct SharedInner[T: Movable](not Movable):
    var strong: Atomic[UInt64]
    var payload: MaybeUninit[Self.T]

    def __init__(out self):
        self.strong = Atomic[UInt64](1)
        self.payload = MaybeUninit[Self.T]()

    def __deinit__(deinit self):
        self.payload^.unsafe_forget()


struct SharedBox[T: Movable & Deinitable](Copyable):
    var inner: Pointer[SharedInner[Self.T], MutUntrackedOrigin]

    def __init__(out self, var value: Self.T):
        var block = alloc(Layout[SharedInner[Self.T]].single()).unsafe_leak()
        block.unsafe_write(
            init_with=lambda () -> SharedInner[Self.T]: SharedInner[Self.T]()
        )
        block[].payload.unsafe_write(value^)
        self.inner = block

    def __init__(out self, *, copy: Self):
        _ = copy.inner[].strong.fetch_add[ordering=Ordering.RELAXED](1)
        self.inner = copy.inner

    def __deinit__(deinit self):
        if self.inner[].strong.fetch_sub[ordering=Ordering.RELEASE](1) != 1:
            return
        fence[ordering=Ordering.ACQUIRE]()
        self.inner[].payload.unsafe_ptr().unsafe_deinit_pointee()
        self.inner.unsafe_deinit_pointee()
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.inner).unsafe_with_layout(
                Layout[SharedInner[Self.T]].single()
            )
        )


struct Connection(Movable):
    var host: String
    var log: Pointer[List[String], MutUntrackedOrigin]

    def __init__(out self, host: String, log: Pointer[List[String], MutUntrackedOrigin]):
        self.host = host
        self.log = log

    def __deinit__(deinit self):
        self.log[].append(String("closed ", self.host))


def main() raises:
    var log = List[String]()
    var log_ptr = Pointer(to=log).unsafe_origin_cast[MutUntrackedOrigin]()

    var primary = SharedBox(Connection("db.internal:5432", log_ptr))
    var replica = primary.copy()
    var reporter = replica.copy()

    log.append("primary released")
    deinit(primary^)
    log.append("reporter released")
    deinit(reporter^)
    log.append("replica released")
    deinit(replica^)  # the last owner closes the connection
    assert_equal(
        log,
        [
            "primary released",
            "reporter released",
            "replica released",
            "closed db.internal:5432",
        ],
    )
