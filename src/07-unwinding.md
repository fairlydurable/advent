# 7. Unwinding

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/builtin/debug_assert.mojo, Mojo/stdlib/std/os/os.mojo, Mojo/stdlib/std/memory/alloc.mojo, Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/collections/list.mojo, Mojo/stdlib/std/traits/anytype.mojo -->

Mojo errors are a typed return path, not unwinding; what runs on that path, how to keep invariants when a call raises, and why aborts skip cleanup.

*Rustonomicon counterpart: Unwinding.*

Mojo has no unwinding. A function that can fail says so with `raises`, and a
raise is a second return path that the compiler checks as carefully as the
first. The caller either handles the error with `try`/`except` or declares
`raises` itself. There is no hidden control flow that can leave a function
from an arbitrary call.

Failures that are not errors (a bounds violation, an `abort`, a failed
assertion) terminate the process. They don't travel up the stack, no
`except` block sees them, and no destructors run on the way out.

So Mojo code faces two separate questions:

1. When a call raises, is every value on the error path in a state you can
   live with? The compiler answers part of this (initialization and linear
   types); you answer the rest (logical invariants).
2. When the process terminates, what work is lost? Anything that only a
   destructor would have done.

Every sample in this chapter lives in
[code/07-unwinding/](code/07-unwinding/).

## 7.1 Exception safety

*Rustonomicon counterpart: Exception Safety.*

### What runs on the error path

A raise ends the raising function along its error edge. Every value still
live in that function dies before control reaches the caller's `except`
block, and `finally` runs after the `except` block. The error itself is an
ordinary value. `raises ParseError` declares its type, and the `except`
binding has that type, fields included.

```mojo
# Claims:
# - `raises ParseError` declares a typed error; the `except` binding has
#   that type, with its fields.
# - Raising is an ordinary return along a second path: every value still
#   live in the raising function is destroyed before the caller's `except`
#   block runs, and `finally` runs after it.
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct ParseError(Movable, Writable):
    var line: Int


struct Buffer(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(out self, name: String, journal: ArcPointer[List[String]]):
        self.name = name
        self.journal = journal

    def __deinit__(deinit self):
        self.journal[].append("free " + self.name)


def parse_line(
    line: Int, journal: ArcPointer[List[String]]
) raises ParseError -> Int:
    var scratch = Buffer("scratch", journal)
    if line > 2:
        raise ParseError(line)
    journal[].append("parsed with " + scratch.name)
    return line * 10


def main() raises:
    var journal = ArcPointer(List[String]())
    try:
        _ = parse_line(7, journal)
    except err:
        journal[].append(String("except line ", err.line))
    finally:
        journal[].append("finally")

    assert_equal(journal[], ["free scratch", "except line 7", "finally"])
```

[code/07-unwinding/raises_is_a_return_path.mojo](code/07-unwinding/raises_is_a_return_path.mojo)

### Constructors that raise

A constructor can raise. What Mojo destroys afterward depends on how much of
`self` exists at the raise point.

If the raise comes before every field holds a value, `self` is not a value
yet. Mojo destroys the fields that were initialized, one at a time, and
skips the struct's `__deinit__`. Fields that were never initialized stay
untouched.

```mojo
# Claims:
# - When `__init__` raises before every field is initialized, Mojo destroys
#   the fields already initialized, one by one, and does not run the
#   struct's `__deinit__`.
# - Fields not yet initialized are never touched.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Resource(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(out self, name: String, journal: ArcPointer[List[String]]):
        self.name = name
        self.journal = journal

    def __deinit__(deinit self):
        self.journal[].append("release " + self.name)


struct Connection(Movable):
    var socket: Resource
    var tls: Resource
    var journal: ArcPointer[List[String]]

    def __init__(
        out self, journal: ArcPointer[List[String]], handshake_ok: Bool
    ) raises:
        self.journal = journal
        self.socket = Resource("socket", journal)
        if not handshake_ok:
            raise Error("handshake failed")
        self.tls = Resource("tls session", journal)

    def __deinit__(deinit self):
        self.journal[].append("Connection.__deinit__")


def main() raises:
    var journal = ArcPointer(List[String]())
    try:
        _ = Connection(journal, handshake_ok=False)
    except e:
        journal[].append(String(e))
    assert_equal(journal[], ["release socket", "handshake failed"])
```

[code/07-unwinding/raising_init_partial.mojo](code/07-unwinding/raising_init_partial.mojo)

If every field holds a value and the constructor has no field writes left,
`self` is complete, and a raise destroys it the usual way: `__deinit__`
runs. That means a destructor can run on a value whose constructor never
finished. A `__deinit__` must not assume that work after field
initialization (registration, a handshake) happened.

```mojo
# Claims:
# - Once `__init__` has initialized every field and has no field writes
#   left, `self` is a complete value. If `__init__` raises after that
#   point, Mojo destroys `self` as a whole, which runs the struct's
#   `__deinit__`.
# - So a `__deinit__` can run on a value whose `__init__` never finished;
#   it must not assume that post-initialization work happened.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Worker(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(
        out self, name: String, journal: ArcPointer[List[String]]
    ) raises:
        self.name = name
        self.journal = journal
        if name == "":
            raise Error("worker needs a name")
        journal[].append("register " + name)

    def __deinit__(deinit self):
        self.journal[].append("Worker.__deinit__")


def main() raises:
    var journal = ArcPointer(List[String]())
    try:
        _ = Worker("", journal)
    except e:
        journal[].append(String(e))
    assert_equal(journal[], ["Worker.__deinit__", "worker needs a name"])
```

[code/07-unwinding/raising_init_complete_runs_deinit.mojo](code/07-unwinding/raising_init_complete_runs_deinit.mojo)

The boundary between the two cases is less obvious than "all fields
assigned". In the next sample, every field holds a value at the raise, but
the constructor writes one of them again afterward. Mojo treats that `self`
as incomplete: it destroys the fields one by one and skips `__deinit__`.

```mojo
# Claims:
# - Whether a raising `__init__` runs `__deinit__` depends on the code after
#   the raise point. Here every field holds a value when the raise happens,
#   but `__init__` writes `status` again afterward, so Mojo treats `self` as
#   incomplete: it destroys the initialized fields one by one and skips
#   `__deinit__`.
# - Design rule that follows: keep required cleanup in field types, and do
#   fallible work before initializing fields that own resources.
from std.memory import ArcPointer
from std.testing import assert_equal


struct Resource(Movable):
    var name: String
    var journal: ArcPointer[List[String]]

    def __init__(out self, name: String, journal: ArcPointer[List[String]]):
        self.name = name
        self.journal = journal

    def __deinit__(deinit self):
        self.journal[].append("release " + self.name)


struct Worker(Movable):
    var socket: Resource
    var status: String
    var journal: ArcPointer[List[String]]

    def __init__(
        out self, name: String, journal: ArcPointer[List[String]]
    ) raises:
        self.journal = journal
        self.socket = Resource("socket", journal)
        self.status = "starting"
        if name == "":
            raise Error("worker needs a name")
        self.status = "ready"

    def __deinit__(deinit self):
        self.journal[].append("Worker.__deinit__")


def main() raises:
    var journal = ArcPointer(List[String]())
    try:
        _ = Worker("", journal)
    except e:
        journal[].append(String(e))
    assert_equal(journal[], ["release socket", "worker needs a name"])
```

[code/07-unwinding/raising_init_later_write_skips_deinit.mojo](code/07-unwinding/raising_init_later_write_skips_deinit.mojo)

Rather than depend on where that boundary falls, follow two rules:

1. Do fallible work before you initialize fields that own resources.
2. Put cleanup that must happen into the field types themselves, so it runs
   whether Mojo destroys the struct as a whole or field by field.

### `mut` arguments are complete on every exit

A `mut` argument must hold a fully initialized value when the function
returns, and the error edge counts as a return. If you move a field out of
`self` and then call something that can raise, the error path would hand the
caller a struct with a hole in it. The compiler rejects that:

```mojo
# EXPECT-ERROR: a raise could leave a field of a mut argument moved out
# EXPECT-MATCH: use of uninitialized value 'self\.items'
# Claim: a `mut` argument must be fully initialized on every exit, and the
# error path counts as an exit. Moving a field out across a call that can
# raise is a compile error.


def validate(reading: Int) raises:
    if reading < 0:
        raise Error("negative reading")


struct Inventory(Movable):
    var items: List[String]

    def __init__(out self):
        self.items = ["bolts"]

    def restock(mut self, reading: Int) raises:
        var taken = self.items^
        validate(reading)
        taken.append("washers")
        self.items = taken^


def main() raises:
    var stock = Inventory()
    stock.restock(3)
```

[code/07-unwinding/mut_field_moved_across_raise_fails.mojo](code/07-unwinding/mut_field_moved_across_raise_fails.mojo)

Restore the field on the error path before re-raising:

```mojo
# Claims:
# - Putting the field back in an `except` block before re-raising satisfies
#   the initialization rule on the error path.
# - The caller then sees the original contents after the failure.
from std.testing import assert_equal


def validate(reading: Int) raises:
    if reading < 0:
        raise Error("negative reading")


struct Inventory(Movable):
    var items: List[String]

    def __init__(out self):
        self.items = ["bolts"]

    def restock(mut self, reading: Int) raises:
        var taken = self.items^
        try:
            validate(reading)
        except e:
            self.items = taken^
            raise e^
        taken.append("washers")
        self.items = taken^


def main() raises:
    var stock = Inventory()
    try:
        stock.restock(-1)
    except e:
        assert_equal(String(e), "negative reading")
    assert_equal(stock.items, ["bolts"])
    stock.restock(3)
    assert_equal(stock.items, ["bolts", "washers"])
```

[code/07-unwinding/restore_field_on_error.mojo](code/07-unwinding/restore_field_on_error.mojo)

### Invariants are your job

The compiler checks initialization on error paths. It doesn't know your
invariants. In the ledger below, both fields stay initialized when
`fee_for` raises, so the code compiles, but money has left one account and
never arrived in the other.

The fix is an ordering discipline: do everything that can raise first, then
commit with operations that can't.

```mojo
# Claims:
# - The compiler checks initialization on error paths, not your invariants.
#   A raise between two related writes leaves both fields initialized and
#   the value inconsistent.
# - Ordering the work as "everything that can raise, then infallible
#   commits" keeps the invariant on every path.
from std.testing import assert_equal, assert_raises


def fee_for(amount: Int) raises -> Int:
    if amount > 10_000:
        raise Error("amount exceeds daily limit")
    return amount // 100


struct Ledger(Movable):
    var checking: Int
    var savings: Int

    def __init__(out self, checking: Int, savings: Int):
        self.checking = checking
        self.savings = savings

    def total(self) -> Int:
        return self.checking + self.savings

    def transfer_unsafe_order(mut self, amount: Int) raises:
        self.checking -= amount
        var fee = fee_for(amount)
        self.savings += amount - fee

    def transfer(mut self, amount: Int) raises:
        var fee = fee_for(amount)
        self.checking -= amount
        self.savings += amount - fee


def main() raises:
    var careless = Ledger(checking=50_000, savings=0)
    with assert_raises(contains="daily limit"):
        careless.transfer_unsafe_order(20_000)
    assert_equal(careless.total(), 30_000)

    var careful = Ledger(checking=50_000, savings=0)
    with assert_raises(contains="daily limit"):
        careful.transfer(20_000)
    assert_equal(careful.total(), 50_000)
```

[code/07-unwinding/broken_invariant_ledger.mojo](code/07-unwinding/broken_invariant_ledger.mojo)

### Holes in unsafe code

Unsafe code that moves an element out of a buffer opens a hole: a slot that
the container counts as initialized but that holds no value. If anything
that can raise runs while the hole is open, the error path must close it,
or the container's destructor will later destroy a value that isn't there.

A hole guard solves this structurally. The guard takes the element out of
its slot when it is created, tracks where the hole currently is, and writes
the element back in its destructor. Normal exit and error exit both run the
destructor, so the buffer always ends up holding every element exactly once.

This insertion sort calls a comparator that can raise. When it raises, the
list is left unsorted but intact:

```mojo
# Claims:
# - Unsafe code that moves an element out of a buffer opens a "hole".
#   If a call that can raise runs while the hole is open, the buffer must
#   still hold valid values when the error leaves the function.
# - A guard whose destructor writes the element back closes the hole on the
#   normal path and on the error path alike.
# - After a raising comparator aborts the sort, the list holds every
#   original element exactly once.
from std.testing import assert_equal, assert_raises, assert_true


struct Hole(Movable):
    var base: Pointer[String, MutUntrackedOrigin]
    var position: Int
    var element: String

    def __init__(
        out self, base: Pointer[String, MutUntrackedOrigin], position: Int
    ):
        self.base = base
        self.position = position
        self.element = base.unsafe_offset(position).unsafe_take_pointee()

    def __deinit__(deinit self):
        self.base.unsafe_offset(self.position).unsafe_write(self.element^)


def insertion_sort(
    mut items: List[String],
    less: Some[def(String, String) raises -> Bool],
) raises:
    var base = items.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    for index in range(1, len(items)):
        var hole = Hole(base, index)
        while hole.position > 0 and less(
            hole.element, base[unsafe_offset=hole.position - 1]
        ):
            base.unsafe_offset(hole.position).unsafe_write_move_from(
                base.unsafe_offset(hole.position - 1)
            )
            hole.position -= 1


def by_hostname(lhs: String, rhs: String) raises -> Bool:
    if lhs == "corrupt-record" or rhs == "corrupt-record":
        raise Error("comparator rejected a record")
    return lhs < rhs


def main() raises:
    var hosts: List[String] = ["web-03", "db-01", "cache-02", "api-04"]
    insertion_sort(hosts, by_hostname)
    assert_equal(hosts, ["api-04", "cache-02", "db-01", "web-03"])

    var original: List[String] = ["web-03", "db-01", "corrupt-record", "api-04"]
    var mixed = original.copy()
    with assert_raises(contains="rejected"):
        insertion_sort(mixed, by_hostname)
    assert_equal(len(mixed), len(original))
    for host in original:
        assert_true(host in mixed)
```

[code/07-unwinding/hole_guard_sort.mojo](code/07-unwinding/hole_guard_sort.mojo)

The guard's destructor is load-bearing here, and the previous chapter showed
that leaking is safe. That's fine in this case because the guard never
escapes the function: no caller can get hold of it to forget it. A guard
that does escape needs the leak-amplification treatment from
[6.3 Leaking](06-ownership-based-resource-management.md#63-leaking).

### Terminating failures

Some failures don't raise at all; they terminate.

List indexing checks bounds by default. A violation ends the process with a
report of the bad index. It isn't an error value, so the compiler warns that
the `except` block below is unreachable, and at run time the program ends
before that block could matter:

```mojo
# EXPECT-EXIT: nonzero
# Claims:
# - List indexing checks bounds by default and terminates the process on a
#   violation. Nothing unwinds and no `except` can catch it.
# - The `try` block below never reaches its `except`.


def main():
    var readings: List[Int] = [12, 14, 9]
    var index = len(readings) + 4
    try:
        print(readings[index])
    except e:
        print("unreachable: bounds failures are not errors", e)
```

[code/07-unwinding/bounds_check_aborts.mojo](code/07-unwinding/bounds_check_aborts.mojo)

`abort` ends the process without running destructors on the path that led to
it. That includes values whose last use came before the call, so don't
count on ASAP destruction to flush anything before an abort:

```mojo
# EXPECT-EXIT: nonzero
# Claims:
# - `abort` terminates the process without unwinding. Destructors on the
#   path to `abort` do not run, even for a value whose last use comes before
#   the call (here `audit` is last read while building the message). A
#   destructor is not a place for work that must survive a crash, such as
#   flushing a journal or releasing a lock file.
# - Expected output: "audit open", then the abort message. The line
#   "audit flushed" never appears.
from std.os import abort


struct AuditLog(Movable):
    var path: String

    def __init__(out self, path: String):
        self.path = path
        print("audit open")

    def __deinit__(deinit self):
        print("audit flushed")


def main():
    var audit = AuditLog("/var/log/payments.audit")
    abort(String("cannot continue with ", audit.path))
```

[code/07-unwinding/abort_skips_destructors.mojo](code/07-unwinding/abort_skips_destructors.mojo)

`debug_assert` is different again. Its checks compile out unless you build
with `-D ASSERT=all`, so in a default build a failing `debug_assert` does
nothing and execution continues. Bounds checks and similar "safe" checks
stay on by default; `-D ASSERT=none` turns those off too, and with them off,
an out-of-bounds index is undefined behavior.

```mojo
# Claims:
# - `debug_assert` checks compile out unless you build with `-D ASSERT=all`.
#   A default build skips this failing check and keeps running.
# - Treat `debug_assert` as documentation that a debug build can enforce,
#   never as a runtime guarantee.
from std.testing import assert_equal


def scale(reading: Int, divisor: Int) -> Int:
    debug_assert(divisor > 0, "divisor must be positive")
    return reading * 4


def main() raises:
    assert_equal(scale(25, 0), 100)
```

[code/07-unwinding/debug_assert_off_by_default.mojo](code/07-unwinding/debug_assert_off_by_default.mojo)

## 7.2 Poisoning

*Rustonomicon counterpart: Poisoning.*

Mojo has no built-in poisoning. Its standard library lock,
`BlockingSpinLock`, has no poison state, and a raise inside a locked region
doesn't mark anything. If a half-finished mutation must block later
readers, you build that.

### A poison flag

The pattern: set a flag before running a mutation that can raise, and clear
it only after the mutation succeeds. A raise skips the clearing, so the flag
stays set, and every later access refuses to run until some code repairs the
value and clears the flag deliberately.

```mojo
# Claims:
# - Mojo has no built-in lock poisoning; you build it from a flag.
# - Set the flag before running a mutation that can raise and clear it only
#   on success. A raise leaves the flag set, and every later access refuses
#   to proceed until someone repairs the value.
from std.testing import assert_equal, assert_raises, assert_true


struct Guarded[T: Movable & Deinitable](Movable):
    var value: Self.T
    var poisoned: Bool

    def __init__(out self, var value: Self.T):
        self.value = value^
        self.poisoned = False

    def update(mut self, mutation: Some[def(mut Self.T) raises -> None]) raises:
        if self.poisoned:
            raise Error("poisoned: an earlier update raised mid-mutation")
        self.poisoned = True
        mutation(self.value)
        self.poisoned = False

    def repair(mut self, var trusted: Self.T):
        self.value = trusted^
        self.poisoned = False


def deposit(mut accounts: List[Int]) raises:
    accounts[0] += 100


def overdrawn_transfer(mut accounts: List[Int]) raises:
    accounts[0] -= 900
    if accounts[0] < 0:
        raise Error("overdraft")
    accounts[1] += 900


def main() raises:
    var balances = Guarded[List[Int]]([500, 250])
    balances.update(deposit)
    assert_equal(balances.value, [600, 250])

    with assert_raises(contains="overdraft"):
        balances.update(overdrawn_transfer)
    assert_true(balances.poisoned)
    # The half-applied transfer is visible: this is the state poisoning
    # protects later callers from.
    assert_equal(balances.value, [-300, 250])

    with assert_raises(contains="poisoned"):
        balances.update(deposit)

    balances.repair([600, 250])
    balances.update(deposit)
    assert_equal(balances.value, [700, 250])
```

[code/07-unwinding/poison_flag.mojo](code/07-unwinding/poison_flag.mojo)

The sample also shows what the flag protects against. After the failed
transfer, the balances hold a half-applied update. Without the flag, the
next deposit would build on it.

### Linear types make error paths impossible to ignore

Poisoning answers "what if someone forgot to handle the error path?" after
the fact. Linear types answer it before the program runs. The compiler
checks every error edge of every call that can raise, and a linear value
live across that edge has to end through a named destructor on that path
too.

`Allocation` is linear, so a raise between `alloc` and `dealloc` is a
compile error:

```mojo
# EXPECT-ERROR: a call that can raise would abandon a live Allocation on its error path
# EXPECT-MATCH: 'frame' abandoned without being explicitly destroyed
# Claim: linear types make error paths visible. The compiler checks the
# error edge of `checksum(...)` and rejects the leak there.
from std.memory import alloc, dealloc, Layout


def checksum(length: Int) raises -> Int:
    if length == 0:
        raise Error("empty frame")
    return length * 31


def process_frame(length: Int) raises -> Int:
    var frame = alloc(Layout[UInt8](length=length))
    var sum = checksum(length)
    dealloc(frame^)
    return sum


def main() raises:
    print(process_frame(64))
```

[code/07-unwinding/allocation_error_path_fails.mojo](code/07-unwinding/allocation_error_path_fails.mojo)

`finally` ends it on both paths with one statement:

```mojo
# Claims:
# - `finally` runs on both the normal and the error path, so a single
#   `dealloc` there satisfies the linear Allocation on every exit.
# - The error still propagates to the caller after `finally` runs.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal, assert_raises


def checksum(length: Int) raises -> Int:
    if length == 0:
        raise Error("empty frame")
    return length * 31


def process_frame(length: Int) raises -> Int:
    var frame = alloc(Layout[UInt8](length=max(length, 1)))
    try:
        return checksum(length)
    finally:
        dealloc(frame^)


def main() raises:
    assert_equal(process_frame(64), 1984)
    with assert_raises(contains="empty frame"):
        _ = process_frame(0)
```

[code/07-unwinding/allocation_error_path_finally.mojo](code/07-unwinding/allocation_error_path_finally.mojo)

An `except` block that releases and re-raises with `raise e^` works as well,
and lets the two paths end the value differently:

```mojo
# Claims:
# - An `except` that releases the resource and re-raises with `raise e^`
#   also satisfies the error edge.
# - The two paths can end the Allocation differently; each path needs
#   exactly one named destructor.
from std.memory import alloc, dealloc, Layout
from std.testing import assert_equal, assert_raises


def checksum(length: Int) raises -> Int:
    if length == 0:
        raise Error("empty frame")
    return length * 31


def process_frame(length: Int) raises -> Int:
    var frame = alloc(Layout[UInt8](length=max(length, 1)))
    var sum: Int
    try:
        sum = checksum(length)
    except e:
        dealloc(frame^)
        raise e^
    dealloc(frame^)
    return sum


def main() raises:
    assert_equal(process_frame(2), 62)
    with assert_raises(contains="empty frame"):
        _ = process_frame(0)
```

[code/07-unwinding/allocation_error_path_except.mojo](code/07-unwinding/allocation_error_path_except.mojo)

The same check works for your own types. A transaction that must be
committed or rolled back is a natural linear type. Forgetting the rollback
on the error path becomes a compile error at the call that can raise:

```mojo
# EXPECT-ERROR: an error path abandons a transaction that must be committed or rolled back
# EXPECT-MATCH: 'txn' abandoned without being explicitly destroyed: finish every transaction
# Claim: a linear transaction type turns "forgot to roll back on error"
# into a compile error at the call that can raise.


struct Transaction(not Deinitable else "finish every transaction with commit() or rollback()"):
    var statements: List[String]

    def __init__(out self):
        self.statements = List[String]()

    def commit(deinit self) -> Int:
        return len(self.statements)

    def rollback(deinit self):
        pass


def validate(statement: String) raises:
    if statement.startswith("DROP"):
        raise Error("refusing destructive statement")


def apply(statements: List[String]) raises -> Int:
    var txn = Transaction()
    for statement in statements:
        validate(statement)
        txn.statements.append(statement)
    return txn^.commit()


def main() raises:
    print(apply(["INSERT INTO audit VALUES (1)"]))
```

[code/07-unwinding/linear_transaction_fails.mojo](code/07-unwinding/linear_transaction_fails.mojo)

With the error edge handled, every caller sees either a commit or a
rollback, never a half-applied transaction:

```mojo
# Claims:
# - Handling the error edge with `rollback()` in an `except` block makes the
#   linear transaction legal on every path.
# - The caller observes the rollback, never a half-applied transaction.
from std.memory import ArcPointer
from std.testing import assert_equal, assert_raises


struct Transaction(not Deinitable else "finish every transaction with commit() or rollback()"):
    var statements: List[String]
    var outcomes: ArcPointer[List[String]]

    def __init__(out self, outcomes: ArcPointer[List[String]]):
        self.statements = List[String]()
        self.outcomes = outcomes

    def commit(deinit self) -> Int:
        self.outcomes[].append(String("commit ", len(self.statements)))
        return len(self.statements)

    def rollback(deinit self):
        self.outcomes[].append(String("rollback ", len(self.statements)))


def validate(statement: String) raises:
    if statement.startswith("DROP"):
        raise Error("refusing destructive statement")


def apply(
    statements: List[String], outcomes: ArcPointer[List[String]]
) raises -> Int:
    var txn = Transaction(outcomes)
    for statement in statements:
        try:
            validate(statement)
        except e:
            txn^.rollback()
            raise e^
        txn.statements.append(statement)
    return txn^.commit()


def main() raises:
    var outcomes = ArcPointer(List[String]())
    assert_equal(apply(["INSERT 1", "INSERT 2"], outcomes), 2)
    with assert_raises(contains="destructive"):
        _ = apply(["INSERT 3", "DROP TABLE audit"], outcomes)
    assert_equal(outcomes[], ["commit 2", "rollback 1"])
```

[code/07-unwinding/linear_transaction.mojo](code/07-unwinding/linear_transaction.mojo)

Between them, these tools replace what poisoning does for unwinding
languages. Initialization checks keep error paths from exposing holes, linear
types force every error path to finish its cleanup, and a poison flag covers
the remaining case: a logical invariant that only a later observer can
notice.
