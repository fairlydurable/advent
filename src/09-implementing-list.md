# 9. Implementing List

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/collections/list.mojo, Mojo/stdlib/std/collections/check_bounds.mojo, Mojo/stdlib/std/memory/alloc.mojo, Mojo/stdlib/std/memory/memory.mojo, Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/memory/maybe_uninit.mojo, Mojo/stdlib/std/traits/deinitable.mojo, Mojo/stdlib/std/iter/__init__.mojo -->

Build a growable array from raw allocations, and see every place where the type system helps and where it steps aside.

This chapter builds `MyList[T]`, a growable array, from nothing but an
allocation and a length. The standard `List` in
`std/collections/list.mojo` follows the same plan with more features. Every
section adds one piece and runs it against the compiler. The finished type,
with its test suite, closes the chapter.

`MyList` tests itself with an element type that counts its own destructor
calls. Most bugs in a hand-built container are destructor bugs: a value
destroyed twice, a value never destroyed, or a moved-out slot destroyed as
though it still held something. Counting turns each of those into a failed
assertion.

```mojo
struct Tracked(Movable):
    """An element that counts its own destructions in a shared counter."""

    var id: Int
    var drops: ArcPointer[Int]

    def __init__(out self, id: Int, drops: ArcPointer[Int]):
        self.id = id
        self.drops = drops

    def __deinit__(deinit self):
        self.drops[] += 1
```

Excerpt from [code/09-implementing-list/push_and_pop.mojo](code/09-implementing-list/push_and_pop.mojo)

`Tracked` keeps its counter behind an `ArcPointer` so that every element can
share one counter. A raw pointer to a local `Int` looks tempting, but its
mutable origin would make the list and each element appear to alias the same
memory, and the exclusivity checker rejects the `push` call.

## 9.1 Layout

*Rustonomicon counterpart: Implementing Vec, Layout.*

A growable array needs three facts: where the storage lives, how many slots
it has, and how many of those slots hold live values. `MyList` stores the
first two in one field and the third in another.

```mojo
struct MyList[T: AnyType](...):
    var _storage: Allocation[Self.T]
    var _len: Int
```

`Allocation[T]` is the handle `alloc()` returns. It pairs a
`ThinAllocation[T]` (the owning pointer) with the `Layout[T]` that produced
it, and the layout records the element count. So the capacity lives in the
allocation, and `len(self._storage)` reads it back. The capacity travels
with the pointer because `dealloc()` needs it: the allocator frees exactly
the layout it handed out, and a mismatched count corrupts the heap.

`ThinAllocation` drops the layout and keeps only the pointer. It suits a
container that tracks capacity some other way. To free one, you pair it with
the original `Layout` again; nothing checks that you supplied the right one.

```mojo
# Claims:
# - A ThinAllocation is one pointer wide; an Allocation adds the element
#   count from its Layout, so it is two words.
# - Allocation plus a length field makes a three-word list header, the same
#   size as the standard List.
# - len() of an Allocation reports the capacity its Layout recorded.
# - Optional[Allocation] costs nothing extra: the null pointer is the niche.

from std.memory import Allocation, Layout, ThinAllocation, alloc, dealloc
from std.sys import size_of
from std.testing import assert_equal


struct MyList[T: AnyType](not Deinitable):  # layout only, never instantiated
    var _storage: Allocation[Self.T]
    var _len: Int


def main() raises:
    comptime word = size_of[Int]()
    assert_equal(size_of[ThinAllocation[Float64]](), word)
    assert_equal(size_of[Allocation[Float64]](), 2 * word)
    assert_equal(size_of[MyList[Float64]](), 3 * word)
    assert_equal(size_of[List[Float64]](), 3 * word)
    assert_equal(size_of[Optional[Allocation[Float64]]](), 2 * word)

    var samples = alloc(Layout[Float64](length=48))
    var capacity = len(samples)
    dealloc(samples^)
    assert_equal(capacity, 48)
```

[code/09-implementing-list/layout_sizes.mojo](code/09-implementing-list/layout_sizes.mojo)

The header comes to three words, the same as the standard `List`. The
`Optional` line shows a free niche: a pointer can't be null, so `Optional`
uses the null address as its `None` and adds no tag.

`Allocation` and `ThinAllocation` are linear types. They declare
`not Deinitable`, so they have no implicit destructor, and the compiler
demands that every value reaches a consuming call such as `dealloc()` or
`unsafe_leak()` on every path. That rule reaches into structs: a field of a
linear type makes the struct's synthesized destructor impossible.

```mojo
# EXPECT-ERROR: a struct with an Allocation field cannot get a synthesized destructor, because Allocation has no implicit destructor
# EXPECT-MATCH: non-'Deinitable' type 'Allocation
# Claim: storing a linear Allocation in a field forces the struct to say how
# it releases that field. Without a __deinit__, the struct cannot be dropped.

from std.memory import Allocation, Layout, alloc


struct SampleBuffer(Movable):
    var storage: Allocation[Float64]

    def __init__(out self):
        self.storage = alloc(Layout[Float64](length=64))


def main():
    var buffer = SampleBuffer()
    _ = buffer^
```

[code/09-implementing-list/linear_field_fails.mojo](code/09-implementing-list/linear_field_fails.mojo)

The fix is a `__deinit__` that consumes the field. `MyList` writes one in
section 9.4. Once it does, the containing struct becomes `Deinitable` again,
and the linearity stays inside the implementation where it belongs.

Round-tripping through the raw pointer shows the full set of handles:

```mojo
# Claims:
# - into_thin() drops the Layout and keeps only the owning pointer.
# - A ThinAllocation must be paired with its original Layout again before
#   dealloc() accepts it.
# - unsafe_leak() consumes the handle; the raw pointer it returns can be
#   re-wrapped as an owning handle.

from std.memory import Layout, ThinAllocation, alloc, dealloc
from std.testing import assert_equal


def main() raises:
    var layout = Layout[Int32](length=16)
    var thin = alloc(layout).into_thin()

    var ports = thin.unsafe_ptr()
    for index in range(16):
        ports.unsafe_offset(index).write(Int32(8000 + index))
    var last_port = ports[unsafe_offset=15]

    var raw = thin^.unsafe_leak()  # the compiler stops tracking the storage
    var owned_again = ThinAllocation(unsafe_owned_ptr=raw)
    dealloc(owned_again^.unsafe_with_layout(layout))

    # Assert after the release: assert_equal can raise, and a raise while the
    # handle is alive would abandon it on the error path.
    assert_equal(last_port, 8015)
```

[code/09-implementing-list/thin_allocation_roundtrip.mojo](code/09-implementing-list/thin_allocation_roundtrip.mojo)

The comment near the end of that sample marks a rule worth learning early.
`assert_equal` can raise. A raise while `thin` or `owned_again` is alive
abandons the handle on the error path, and the compiler rejects the program.
Every raising call between `alloc` and `dealloc` counts:

```mojo
# EXPECT-ERROR: a call that can raise between alloc and dealloc abandons the allocation on the error path
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim: the compiler checks every exit path, including the hidden one that
# each raising call adds, for a live Allocation.

from std.memory import Layout, alloc, dealloc


def parse_port(text: String) raises -> Int:
    return Int(text)


def main() raises:
    var ports = alloc(Layout[Int].single())
    ports.unsafe_ptr().write(parse_port("8080"))  # can raise
    dealloc(ports^)
```

[code/09-implementing-list/raising_path_leak_fails.mojo](code/09-implementing-list/raising_path_leak_fails.mojo)

## 9.2 Allocating

*Rustonomicon counterpart: Implementing Vec, Allocating Memory.*

An empty list should not allocate. `MyList()` starts with a placeholder
allocation: a dangling, well-aligned pointer wrapped in a zero-length layout.

```mojo
    @staticmethod
    def _dangling() -> Allocation[Self.T]:
        return ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))
```

Excerpt from [code/09-implementing-list/growth_policy.mojo](code/09-implementing-list/growth_policy.mojo)

The placeholder never came from the allocator, so it must never reach
`dealloc()`. Passing it would hand `free` an address that `malloc` never
returned, which is undefined behavior. `_release` routes zero-capacity
storage to `unsafe_leak()` instead, which consumes the handle and does
nothing else:

```mojo
    @staticmethod
    def _release(var storage: Allocation[Self.T]):
        if len(storage) > 0:
            dealloc(storage^)
        else:
            _ = storage^.unsafe_leak()  # never came from the allocator
```

Excerpt from [code/09-implementing-list/growth_policy.mojo](code/09-implementing-list/growth_policy.mojo)

`unsafe_dangling()` returns an address that might coincide with a real
allocation. Track "has storage" through the capacity, never by comparing the
pointer against the dangling value.

Growth doubles the capacity, starting from one. Doubling keeps `push`
amortized constant-time: a list that reaches length n has copied fewer than
2n elements in total.

```mojo
    def _grow(mut self) where conforms_to(Self.T, Movable):
        var fresh = alloc(Layout[Self.T](length=max(1, self.capacity() * 2)))
        unsafe_uninit_move_n[overlapping=False](
            dest=fresh.unsafe_ptr(),
            src=self._storage.unsafe_ptr(),
            count=self._len,
        )
        var old = self._storage^
        self._storage = fresh^
        Self._release(old^)
```

Excerpt from [code/09-implementing-list/growth_policy.mojo](code/09-implementing-list/growth_policy.mojo)

The order of the last three lines matters. `self._storage^` moves the old
allocation out of the field and leaves the field uninitialized; the next
line initializes it again; then the old block goes to `_release`. Skip the
release and the compiler catches the leak:

```mojo
# EXPECT-ERROR: replacing an Allocation field without releasing the old one abandons it
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim: a growth routine that overwrites its storage field without
# deallocating the old block does not compile. The leak is a type error.

from std.memory import Allocation, Layout, alloc, dealloc


struct Readings(Movable):
    var _storage: Allocation[Float64]

    def __init__(out self):
        self._storage = alloc(Layout[Float64](length=4))

    def grow(mut self):
        var old = self._storage^
        self._storage = alloc(Layout[Float64](length=len(old) * 2))
        # forgot: dealloc(old^)

    def __deinit__(deinit self):
        dealloc(self._storage^)


def main():
    var readings = Readings()
    readings.grow()
```

[code/09-implementing-list/abandoned_storage_fails.mojo](code/09-implementing-list/abandoned_storage_fails.mojo)

The full growth sequence, including the zero-capacity start:

```mojo
def main() raises:
    var cities = MyList[String]()
    assert_equal(cities.capacity(), 0)
    var dangling = Pointer[String, MutUntrackedOrigin].unsafe_dangling()
    assert_equal(Int(cities._storage.unsafe_ptr()), Int(dangling))

    var capacities = List[Int]()
    for city in ["Oslo", "Lima", "Pune", "Kyiv", "Graz"]:
        cities.push(city)
        capacities.append(cities.capacity())
    assert_equal(capacities, [1, 2, 4, 4, 8])
```

Excerpt from [code/09-implementing-list/growth_policy.mojo](code/09-implementing-list/growth_policy.mojo)

`Layout(length=)` checks its count at run time. A negative length aborts the
program before it can reach the allocator:

```mojo
# EXPECT-EXIT: nonzero
# Claim: Layout(length=) checks its count at run time and aborts on a
# negative length instead of handing a nonsense size to the allocator.

from std.memory import Layout


def main():
    var requested = -3
    var layout = Layout[Float64](length=requested)
    print(len(layout))
```

[code/09-implementing-list/negative_layout_aborts.mojo](code/09-implementing-list/negative_layout_aborts.mojo)

## 9.3 Push and pop

*Rustonomicon counterpart: Implementing Vec, Push and Pop.*

The slots past `_len` hold uninitialized memory. Writing into one must not
run a destructor on whatever bits it holds, and reading one out must leave it
uninitialized without running a destructor either. `Pointer` names both
operations:

- `unsafe_write(value^)` moves `value` into the pointee and assumes the
  pointee holds nothing.
- `unsafe_take_pointee()` moves the pointee out and leaves the slot
  uninitialized.

```mojo
    def push(mut self, var value: Self.T) where conforms_to(Self.T, Movable):
        if self._len == self.capacity():
            self._grow()
        self._storage.unsafe_ptr().unsafe_offset(self._len).unsafe_write(
            value^
        )
        self._len += 1
```

Excerpt from [code/09-implementing-list/push_and_pop.mojo](code/09-implementing-list/push_and_pop.mojo)

```mojo
    def pop(mut self) -> Optional[Self.T] where conforms_to(Self.T, Movable):
        if self._len == 0:
            return None
        self._len -= 1
        return self._storage.unsafe_ptr().unsafe_offset(
            self._len
        ).unsafe_take_pointee()
```

Excerpt from [code/09-implementing-list/push_and_pop.mojo](code/09-implementing-list/push_and_pop.mojo)

`pop` decrements `_len` before it takes the value. The list's view of which
slots are live changes first, so no code path can observe a length that
counts a moved-out slot.

Both methods carry `where conforms_to(Self.T, Movable)`. The struct accepts
any `T: AnyType`, including types that can't move, and only the methods that
relocate elements demand `Movable`. A `MyList` of non-movable values still
type-checks; it can't call `push`.

```mojo
def main() raises:
    var drops = ArcPointer(0)
    var parts = MyList[Tracked]()
    for id in range(5):
        parts.push(Tracked(id, drops))  # grows three times along the way
    assert_equal(drops[], 0)

    var last = parts.pop()
    assert_equal(drops[], 0)  # moved out, not destroyed
    assert_equal(last.value().id, 4)
    assert_equal(drops[], 1)  # `last` died at its final use, the line above
    assert_equal(len(parts), 4)
```

Excerpt from [code/09-implementing-list/push_and_pop.mojo](code/09-implementing-list/push_and_pop.mojo)

The counts tell the story. Five pushes and three reallocations run zero
destructors, because relocation moves bits and ends the source's lifetime
without a destructor call. `pop` runs none either. The popped value dies one
line later, at its last use, because Mojo destroys a value as soon as
nothing uses it again. Assertions about destructor counts have to account for
that timing; section 9.11 shows how.

## 9.4 Deallocating

*Rustonomicon counterpart: Implementing Vec, Deallocating.*

The destructor destroys the live prefix and releases the storage. The slots
between `_len` and the capacity hold nothing, so it must not touch them.

```mojo
    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        unsafe_destroy_n(self._storage.unsafe_ptr(), self._len)
        Self._release(self._storage^)
```

Excerpt from [code/09-implementing-list/destructor_counts.mojo](code/09-implementing-list/destructor_counts.mojo)

`unsafe_destroy_n` runs the destructor of each element in place. For a type
with a trivial destructor, such as `Int` or `Float64`, it compiles to
nothing.

The `where` clause on `__deinit__` pairs with a conditional conformance on
the struct:

```mojo
struct MyList[T: AnyType](
    Movable,
    Sized,
    Deinitable where conforms_to(T, Deinitable) else (
        "a MyList of non-Deinitable elements needs an explicit"
        " deinit_with() call"
    ),
):
```

Excerpt from [code/09-implementing-list/destructor_counts.mojo](code/09-implementing-list/destructor_counts.mojo)

`MyList[T]` is `Deinitable` exactly when `T` is. For other element types the
list itself becomes linear, and the compiler prints the message from the
`else` clause when someone abandons one:

```mojo
# EXPECT-ERROR: a MyList of linear elements cannot be abandoned; it needs deinit_with()
# EXPECT-MATCH: abandoned without being explicitly destroyed: a MyList of non-Deinitable
# Claims:
# - A struct holding a non-Deinitable element type cannot be dropped
#   implicitly: MyList is Deinitable only where T is.
# - The compiler reports the custom message from the conditional conformance.

from std.memory import (
    Allocation,
    ArcPointer,
    Layout,
    ThinAllocation,
    alloc,
    dealloc,
    unsafe_destroy_n,
    unsafe_uninit_move_n,
)
from std.testing import assert_equal, assert_true


struct MyList[T: AnyType](
    Movable,
    Sized,
    Deinitable where conforms_to(T, Deinitable) else (
        "a MyList of non-Deinitable elements needs an explicit"
        " deinit_with() call"
    ),
):
    var _storage: Allocation[Self.T]
    var _len: Int

    def __init__(out self):
        self._storage = Self._dangling()
        self._len = 0

    @staticmethod
    def _dangling() -> Allocation[Self.T]:
        return ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))

    @staticmethod
    def _release(var storage: Allocation[Self.T]):
        if len(storage) > 0:
            dealloc(storage^)
        else:
            _ = storage^.unsafe_leak()  # never came from the allocator

    def __len__(self) -> Int:
        return self._len

    def capacity(self) -> Int:
        return len(self._storage)

    def _grow(mut self) where conforms_to(Self.T, Movable):
        var fresh = alloc(Layout[Self.T](length=max(1, self.capacity() * 2)))
        unsafe_uninit_move_n[overlapping=False](
            dest=fresh.unsafe_ptr(),
            src=self._storage.unsafe_ptr(),
            count=self._len,
        )
        var old = self._storage^
        self._storage = fresh^
        Self._release(old^)

    def push(mut self, var value: Self.T) where conforms_to(Self.T, Movable):
        if self._len == self.capacity():
            self._grow()
        self._storage.unsafe_ptr().unsafe_offset(self._len).unsafe_write(
            value^
        )
        self._len += 1

    def pop(mut self) -> Optional[Self.T] where conforms_to(Self.T, Movable):
        if self._len == 0:
            return None
        self._len -= 1
        return self._storage.unsafe_ptr().unsafe_offset(
            self._len
        ).unsafe_take_pointee()

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        unsafe_destroy_n(self._storage.unsafe_ptr(), self._len)
        Self._release(self._storage^)

    def deinit_with(deinit self, deinit_func: Some[def(var Self.T)], /):
        var data = self._storage.unsafe_ptr()
        for index in range(self._len):
            data.unsafe_offset(index).unsafe_deinit_pointee_with(deinit_func)
        Self._release(self._storage^)


struct Ticket(Movable, not Deinitable):
    var seat: Int

    def __init__(out self, seat: Int):
        self.seat = seat

    def redeem(deinit self) -> Int:
        return self.seat


def main():
    var tickets = MyList[Ticket]()
    tickets.push(Ticket(12))
```

[code/09-implementing-list/non_deinitable_elements_fails.mojo](code/09-implementing-list/non_deinitable_elements_fails.mojo)

A list of linear elements needs an explicit destructor that tells it how to
consume each element. `deinit_with` takes a function that receives each
element by value:

```mojo
    def deinit_with(deinit self, deinit_func: Some[def(var Self.T)], /):
        var data = self._storage.unsafe_ptr()
        for index in range(self._len):
            data.unsafe_offset(index).unsafe_deinit_pointee_with(deinit_func)
        Self._release(self._storage^)
```

Excerpt from [code/09-implementing-list/deinit_with_tickets.mojo](code/09-implementing-list/deinit_with_tickets.mojo)

```mojo
def main() raises:
    var tickets = MyList[Ticket]()
    for seat in [12, 14, 15]:
        tickets.push(Ticket(seat))

    var seats_redeemed = 0

    def redeem(var ticket: Ticket) {mut seats_redeemed}:
        seats_redeemed += ticket^.redeem()

    tickets^.deinit_with(redeem)
    assert_equal(seats_redeemed, 41)
```

Excerpt from [code/09-implementing-list/deinit_with_tickets.mojo](code/09-implementing-list/deinit_with_tickets.mojo)

The destructor count for a full list, with `deinit(value^)` pinning the
destruction to a specific line:

```mojo
def main() raises:
    var drops = ArcPointer(0)
    var parts = MyList[Tracked]()
    for id in range(5):
        parts.push(Tracked(id, drops))
    _ = parts.pop()  # the popped temporary dies immediately
    assert_equal(drops[], 1)
    assert_equal(parts.capacity(), 8)  # three slots were never written

    deinit(parts^)  # destroy here
    assert_equal(drops[], 5)  # four live elements, plus the popped one
```

Excerpt from [code/09-implementing-list/destructor_counts.mojo](code/09-implementing-list/destructor_counts.mojo)

The `deinit` built-in takes ownership of a value and destroys it right there.
Without it, `parts` would die at its last use, the `capacity()` call, and the
final assertion would run after the fact.

## 9.5 Deref

*Rustonomicon counterpart: Implementing Vec, Deref.*

Mojo has no implicit dereference to a slice type. A container exposes its
elements through `__getitem__` and through a `Span` view. Both return
references into heap memory, and the origin on each reference decides what
the compiler can check.

The first attempt returns `ref[self]`:

```mojo
def __getitem__(ref self, index: Int) -> ref[self] Self.T:
    check_bounds(index, length=self._len)
    return self._storage.unsafe_ptr().unsafe_offset(index)[]
```

The compiler rejects the body. `self._storage.unsafe_ptr()` returns a pointer
whose origin is the field `self._storage`, and a reference with a field
origin does not convert to one with the whole-`self` origin. Origins are
field-precise. The fix casts the pointer to the caller's origin explicitly,
which is what `unsafe_ptr()` on `MyList` does:

```mojo
    def unsafe_ptr[
        origin: Origin, //
    ](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()
```

Excerpt from [code/09-implementing-list/index_and_span.mojo](code/09-implementing-list/index_and_span.mojo)

With that cast, the `ref[self]` version compiles and works. It also has a
hole. The returned reference keeps `self` alive, but nothing stops a `push`
while the reference lives, and a `push` may move every element to a new
buffer:

```mojo
# Undefined behavior with a ref[self] __getitem__: `first` dangles
var cities = MyList[String]()
cities.push("Oslo")
ref first = cities[0]
cities.push("Lima")  # reallocates; frees the buffer `first` points into
print(first)
```

The compiler accepts that program. The origin system tracks liveness, and it
checks exclusivity among the arguments of a single call, but a reference
bound on one line does not block a mutation on the next.

The standard `List` closes the hole with an interior origin, and `MyList`
copies the technique:

```mojo
    comptime _Elements[origin: Origin] = origin._get_owned_interior["element"]
```

Excerpt from [code/09-implementing-list/index_and_span.mojo](code/09-implementing-list/index_and_span.mojo)

```mojo
    @__unsafe_nested_origins_read_only
    def __getitem__(
        ref self, index: Int
    ) -> ref[Self._Elements[origin_of(self)]] Self.T:
        check_bounds(index, length=self._len)
        return self.unsafe_ptr().unsafe_offset(
            index
        )._get_ref_with_unsafe_interior_origin["element", origin_of(self)]()
```

Excerpt from [code/09-implementing-list/index_and_span.mojo](code/09-implementing-list/index_and_span.mojo)

`origin._get_owned_interior["element"]` names memory the list owns
indirectly, inside its heap buffer. A reference with that origin becomes
invalid the moment anything mutates the list, and any later use is a compile
error:

```mojo
# EXPECT-ERROR: an element reference held across push is invalidated, because push may reallocate the buffer
# EXPECT-MATCH: use of invalidated interior reference
# Claim: with an interior origin on __getitem__, any mutation of the list
# invalidates outstanding element references, so a stale reference into a
# freed buffer cannot compile.

from std.memory import (
    Allocation,
    ArcPointer,
    Layout,
    ThinAllocation,
    alloc,
    dealloc,
    unsafe_destroy_n,
    unsafe_uninit_move_n,
)
from std.collections import check_bounds
from std.testing import assert_equal, assert_true


struct MyList[T: AnyType](
    Movable,
    Sized,
    Deinitable where conforms_to(T, Deinitable) else (
        "a MyList of non-Deinitable elements needs an explicit"
        " deinit_with() call"
    ),
):
    var _storage: Allocation[Self.T]
    var _len: Int

    def __init__(out self):
        self._storage = Self._dangling()
        self._len = 0

    @staticmethod
    def _dangling() -> Allocation[Self.T]:
        return ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))

    @staticmethod
    def _release(var storage: Allocation[Self.T]):
        if len(storage) > 0:
            dealloc(storage^)
        else:
            _ = storage^.unsafe_leak()  # never came from the allocator

    def __len__(self) -> Int:
        return self._len

    def capacity(self) -> Int:
        return len(self._storage)

    def _grow(mut self) where conforms_to(Self.T, Movable):
        var fresh = alloc(Layout[Self.T](length=max(1, self.capacity() * 2)))
        unsafe_uninit_move_n[overlapping=False](
            dest=fresh.unsafe_ptr(),
            src=self._storage.unsafe_ptr(),
            count=self._len,
        )
        var old = self._storage^
        self._storage = fresh^
        Self._release(old^)

    def push(mut self, var value: Self.T) where conforms_to(Self.T, Movable):
        if self._len == self.capacity():
            self._grow()
        self._storage.unsafe_ptr().unsafe_offset(self._len).unsafe_write(
            value^
        )
        self._len += 1

    def pop(mut self) -> Optional[Self.T] where conforms_to(Self.T, Movable):
        if self._len == 0:
            return None
        self._len -= 1
        return self._storage.unsafe_ptr().unsafe_offset(
            self._len
        ).unsafe_take_pointee()


    # Experimental: element references live in an interior origin, so any
    # mutation of the list invalidates them.
    comptime _Elements[origin: Origin] = origin._get_owned_interior["element"]

    def unsafe_ptr[
        origin: Origin, //
    ](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    @__unsafe_nested_origins_read_only
    def __getitem__(
        ref self, index: Int
    ) -> ref[Self._Elements[origin_of(self)]] Self.T:
        check_bounds(index, length=self._len)
        return self.unsafe_ptr().unsafe_offset(
            index
        )._get_ref_with_unsafe_interior_origin["element", origin_of(self)]()

    def as_span(ref self) -> Span[Self.T, origin_of(self)]:
        return Span(unsafe_ptr=self.unsafe_ptr(), length=self._len)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        unsafe_destroy_n(self._storage.unsafe_ptr(), self._len)
        Self._release(self._storage^)

    def deinit_with(deinit self, deinit_func: Some[def(var Self.T)], /):
        var data = self._storage.unsafe_ptr()
        for index in range(self._len):
            data.unsafe_offset(index).unsafe_deinit_pointee_with(deinit_func)
        Self._release(self._storage^)


def main():
    var cities = MyList[String]()
    cities.push("Oslo")
    ref first = cities[0]
    cities.push("Lima")  # may move every element to a new buffer
    print(first)
```

[code/09-implementing-list/stale_reference_fails.mojo](code/09-implementing-list/stale_reference_fails.mojo)

Without `@__unsafe_nested_origins_read_only`, taking a second reference
through `__getitem__` on a mutable list counts as a mutation and invalidates
the first. With it, two element references can coexist, as they do on the
standard `List`. Both spellings start with an
underscore: they are experimental, and the standard library uses them on
this branch without promising them to user code. Treat them as the current
best tool, with a version pin.

`check_bounds` runs on every index. It's on by default for CPU code and
compiled out by default for GPU code, and `-D ASSERT=none` turns it off
everywhere:

```mojo
# EXPECT-EXIT: nonzero
# Claim: __getitem__ checks bounds with check_bounds, which is on by default
# for CPU code and aborts the program on an out-of-range index.

from std.memory import (
    Allocation,
    ArcPointer,
    Layout,
    ThinAllocation,
    alloc,
    dealloc,
    unsafe_destroy_n,
    unsafe_uninit_move_n,
)
from std.collections import check_bounds
from std.testing import assert_equal, assert_true


struct MyList[T: AnyType](
    Movable,
    Sized,
    Deinitable where conforms_to(T, Deinitable) else (
        "a MyList of non-Deinitable elements needs an explicit"
        " deinit_with() call"
    ),
):
    var _storage: Allocation[Self.T]
    var _len: Int

    def __init__(out self):
        self._storage = Self._dangling()
        self._len = 0

    @staticmethod
    def _dangling() -> Allocation[Self.T]:
        return ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))

    @staticmethod
    def _release(var storage: Allocation[Self.T]):
        if len(storage) > 0:
            dealloc(storage^)
        else:
            _ = storage^.unsafe_leak()  # never came from the allocator

    def __len__(self) -> Int:
        return self._len

    def capacity(self) -> Int:
        return len(self._storage)

    def _grow(mut self) where conforms_to(Self.T, Movable):
        var fresh = alloc(Layout[Self.T](length=max(1, self.capacity() * 2)))
        unsafe_uninit_move_n[overlapping=False](
            dest=fresh.unsafe_ptr(),
            src=self._storage.unsafe_ptr(),
            count=self._len,
        )
        var old = self._storage^
        self._storage = fresh^
        Self._release(old^)

    def push(mut self, var value: Self.T) where conforms_to(Self.T, Movable):
        if self._len == self.capacity():
            self._grow()
        self._storage.unsafe_ptr().unsafe_offset(self._len).unsafe_write(
            value^
        )
        self._len += 1

    def pop(mut self) -> Optional[Self.T] where conforms_to(Self.T, Movable):
        if self._len == 0:
            return None
        self._len -= 1
        return self._storage.unsafe_ptr().unsafe_offset(
            self._len
        ).unsafe_take_pointee()


    # Experimental: element references live in an interior origin, so any
    # mutation of the list invalidates them.
    comptime _Elements[origin: Origin] = origin._get_owned_interior["element"]

    def unsafe_ptr[
        origin: Origin, //
    ](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    @__unsafe_nested_origins_read_only
    def __getitem__(
        ref self, index: Int
    ) -> ref[Self._Elements[origin_of(self)]] Self.T:
        check_bounds(index, length=self._len)
        return self.unsafe_ptr().unsafe_offset(
            index
        )._get_ref_with_unsafe_interior_origin["element", origin_of(self)]()

    def as_span(ref self) -> Span[Self.T, origin_of(self)]:
        return Span(unsafe_ptr=self.unsafe_ptr(), length=self._len)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        unsafe_destroy_n(self._storage.unsafe_ptr(), self._len)
        Self._release(self._storage^)

    def deinit_with(deinit self, deinit_func: Some[def(var Self.T)], /):
        var data = self._storage.unsafe_ptr()
        for index in range(self._len):
            data.unsafe_offset(index).unsafe_deinit_pointee_with(deinit_func)
        Self._release(self._storage^)


def main():
    var cities = MyList[String]()
    cities.push("Oslo")
    var requested = 3
    print(cities[requested])
```

[code/09-implementing-list/out_of_bounds_aborts.mojo](code/09-implementing-list/out_of_bounds_aborts.mojo)

The abort report names a line inside `__getitem__`, not the caller's line.
`check_bounds` walks up a fixed number of inlined frames to find the caller,
and the standard `List` marks its `__getitem__` `@inline(.always)` so that the
count comes out right.

A `Span` view carries its own length, and its origin is the list:

```mojo
def main() raises:
    var readings = MyList[Float64]()
    for celsius in [21.5, 22.0, 23.25]:
        readings.push(celsius)
    readings[1] = 22.75

    ref coldest = readings[0]
    ref warmest = readings[2]
    assert_equal(warmest - coldest, 1.75)

    var total = 0.0
    for reading in readings.as_span():
        total += reading
    assert_equal(total, 67.5)
```

Excerpt from [code/09-implementing-list/index_and_span.mojo](code/09-implementing-list/index_and_span.mojo)

Field-precise origins matter inside the implementation too. A pointer derived
from all of `mut self` may reach `self._len`, so passing both into one call
breaks exclusivity. That's why `push` and `pop` derive the pointer from
`self._storage` alone:

```mojo
# EXPECT-ERROR: a pointer derived from all of mutable self aliases self._len, so passing both into one call violates exclusivity
# EXPECT-MATCH: aliasing values passed mutably
# Claim: a pointer typed with origin_of(self) may reach every field of self,
# so the compiler rejects reading self._len in the same call. Deriving the
# pointer from the storage field alone (origin_of(self._storage)) compiles.

from std.memory import Allocation, Layout, alloc, dealloc


struct Readings(Movable):
    var _storage: Allocation[Float64]
    var _len: Int

    def __init__(out self):
        self._storage = alloc(Layout[Float64](length=8))
        self._len = 0

    def whole_self_ptr[
        origin: Origin, //
    ](ref[origin] self) -> Pointer[Float64, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    def push_field_precise(mut self, celsius: Float64):
        self._storage.unsafe_ptr().unsafe_offset(self._len).write(celsius)
        self._len += 1

    def push_whole_self(mut self, celsius: Float64):
        self.whole_self_ptr().unsafe_offset(self._len).write(celsius)
        self._len += 1

    def __deinit__(deinit self):
        dealloc(self._storage^)


def main():
    var readings = Readings()
    readings.push_field_precise(21.5)
    readings.push_whole_self(22.0)
```

[code/09-implementing-list/self_aliasing_fails.mojo](code/09-implementing-list/self_aliasing_fails.mojo)

## 9.6 Insert and remove

*Rustonomicon counterpart: Implementing Vec, Insert and Remove.*

Inserting at an index shifts the tail up one slot; removing shifts it down.
The source and destination ranges overlap, and the elements must relocate,
not copy, so no destructor runs.

`unsafe_uninit_move_n[overlapping=True]` does the shift. For trivially
movable types it becomes one `memmove`. For other types it moves element by
element, back to front when the destination sits above the source, so no
element overwrites one that hasn't moved yet. The destination slots must hold
nothing live: the function overwrites them without destroying anything.

```mojo
    def insert(
        mut self, index: Int, var value: Self.T
    ) where conforms_to(Self.T, Movable):
        check_bounds(index, length=self._len + 1)
        if self._len == self.capacity():
            self._buf.grow(self._len)
        var data = self.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(index + 1),
            src=data.unsafe_offset(index),
            count=self._len - index,
        )
        data.unsafe_offset(index).unsafe_write(value^)
        self._len += 1
```

Excerpt from [code/09-implementing-list/insert_and_remove.mojo](code/09-implementing-list/insert_and_remove.mojo)

```mojo
    def remove(mut self, index: Int) -> Self.T where conforms_to(Self.T, Movable):
        check_bounds(index, length=self._len)
        var data = self.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
        var removed = data.unsafe_offset(index).unsafe_take_pointee()
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(index),
            src=data.unsafe_offset(index + 1),
            count=self._len - index - 1,
        )
        self._len -= 1
        return removed^
```

Excerpt from [code/09-implementing-list/insert_and_remove.mojo](code/09-implementing-list/insert_and_remove.mojo)

Both methods cast the base pointer to `MutUntrackedOrigin` before the shift.
`dest` and `src` both come from one buffer, so with a tracked origin both
pointers claim mutable access to the same origin, and the exclusivity checker
rejects the call even though the two ranges address different slots:

```mojo
# EXPECT-ERROR: two pointers derived from the same tracked mutable origin cannot both go to a call that takes them mutably
# EXPECT-MATCH: aliasing values passed mutably to 'dest' argument and passed mutably to 'src' argument
# Claim: the exclusivity checker does not know that dest and src address
# different slots, so shifting elements inside one buffer through tracked
# pointers fails. Casting the base pointer to MutUntrackedOrigin first (as
# MyList.insert and the standard List do) takes the call out of the checker's
# view and makes the overlap your responsibility.

from std.memory import Layout, alloc, dealloc, unsafe_uninit_move_n


def shift_right(mut storage: List[Int], count: Int):
    var data = storage.unsafe_ptr()  # origin: origin_of(storage), mutable
    unsafe_uninit_move_n[overlapping=True](
        dest=data.unsafe_offset(1), src=data.unsafe_offset(0), count=count
    )


def main():
    var ports: List[Int] = [8080, 8081, 8082, 0]
    shift_right(ports, 3)
```

[code/09-implementing-list/tracked_origin_move_fails.mojo](code/09-implementing-list/tracked_origin_move_fails.mojo)

An untracked origin promises that the pointer aliases nothing the compiler
manages. The checker steps aside, and keeping the overlap correct becomes
your job. The standard `List` makes the same cast in `insert` and `pop(i)`,
with a comment saying why.

```mojo
# Claims:
# - Casting to MutUntrackedOrigin lets one buffer act as both dest and src
#   of an overlapping move.
# - overlapping=True moves back to front when dest sits above src, so no
#   element overwrites one that has not moved yet.

from std.memory import unsafe_uninit_move_n
from std.testing import assert_equal


def shift_right(mut storage: List[Int], count: Int):
    var data = storage.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    unsafe_uninit_move_n[overlapping=True](
        dest=data.unsafe_offset(1), src=data.unsafe_offset(0), count=count
    )


def main() raises:
    var ports: List[Int] = [8080, 8081, 8082, 0]
    shift_right(ports, 3)
    ports[0] = 443  # slot 0 still holds its old bits; overwrite it
    assert_equal(ports, [443, 8080, 8081, 8082])
```

[code/09-implementing-list/untracked_shift.mojo](code/09-implementing-list/untracked_shift.mojo)

With destructor counts:

```mojo
def main() raises:
    var drops = ArcPointer(0)
    var parts = MyList[Tracked]()
    for id in range(4):
        parts.push(Tracked(id, drops))

    parts.insert(1, Tracked(40, drops))  # ids now 0, 40, 1, 2, 3
    assert_equal(parts[1].id, 40)
    assert_equal(parts[4].id, 3)

    var removed = parts.remove(0)  # ids now 40, 1, 2, 3
    assert_equal(parts[0].id, 40)
    assert_equal(drops[], 0)  # every shift was a relocation
    assert_equal(removed.id, 0)
    assert_equal(drops[], 1)  # `removed` died after its last use
    assert_equal(len(parts), 4)
```

Excerpt from [code/09-implementing-list/insert_and_remove.mojo](code/09-implementing-list/insert_and_remove.mojo)

`remove` takes the element out first, then shifts. Taking first means that
the slot at `index` is uninitialized when the shift overwrites it, which is
exactly what `unsafe_uninit_move_n` requires of its destination.

## 9.7 IntoIter

*Rustonomicon counterpart: Implementing Vec, IntoIter.*

An owning iterator consumes the list and yields elements by value. It owns
the list outright, so it needs no origin at all:

```mojo
struct IntoIter[T: Movable & Deinitable](Iterator, Movable):
    comptime Element = Self.T
    var _list: MyList[Self.T]
    var _next: Int

    def __init__(out self, var list: MyList[Self.T]):
        self._list = list^
        self._next = 0

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.T:
        if self._next == len(self._list):
            raise StopIteration()
        self._next += 1
        return self._list.unsafe_ptr().unsafe_offset(
            self._next - 1
        ).unsafe_take_pointee()

    def __deinit__(deinit self):
        # Slots before _next already moved out; destroy only the rest, then
        # tell the list it holds nothing so its own destructor skips them.
        var data = self._list.unsafe_ptr()
        unsafe_destroy_n(
            data.unsafe_offset(self._next), len(self._list) - self._next
        )
        self._list._len = 0
```

Excerpt from [code/09-implementing-list/into_iter.mojo](code/09-implementing-list/into_iter.mojo)

A Mojo iterator signals the end by raising `StopIteration` from `__next__`,
and its `Element` must be `Movable`. `__iter__(var self)` returning `self^`
lets a `for` loop accept the iterator directly.

The destructor is where the care goes. Slots before `_next` already moved
out. Destroying them again would run destructors on moved-out memory, so the
iterator destroys only the rest, then sets the inner list's length to zero
so that the list's own destructor, which runs right after, finds nothing to
destroy. The list releases the buffer.

`MyList.__iter__(var self)` hands the list to the iterator, so `for part in
parts^` consumes it:

```mojo
def main() raises:
    var drops = ArcPointer(0)
    var parts = MyList[Tracked]()
    for id in range(5):
        parts.push(Tracked(id, drops))

    var yielded = List[Int]()
    for part in parts^:
        yielded.append(part.id)
        if part.id == 1:
            break
    assert_equal(yielded, [0, 1])
    assert_equal(drops[], 5)  # two yielded and dropped, three destroyed unseen
```

Excerpt from [code/09-implementing-list/into_iter.mojo](code/09-implementing-list/into_iter.mojo)

Breaking out of the loop early destroys the iterator, which destroys the
three elements the loop never saw. Each element dies exactly once.

## 9.8 RawBuffer

*Rustonomicon counterpart: Implementing Vec, RawVec.*

Two types now repeat the same allocation logic: the list, and anything else
built on a growable buffer. Factoring the allocation into its own type
separates two jobs. `RawBuffer[T]` owns memory and knows nothing about which
slots hold values. `MyList[T]` knows which slots hold values and delegates
memory to the buffer.

`RawBuffer` is linear. Its named destructor, `release()`, frees the memory
and does nothing about elements, because it can't know about them. Making it
linear forces every owner to call `release()` deliberately, after deciding
what to do with the elements:

```mojo
struct RawBuffer[T: AnyType](Movable, not Deinitable):
    var _storage: Allocation[Self.T]

    def __init__(out self):
        self._storage = ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))

    def capacity(self) -> Int:
        comptime if size_of[Self.T]() == 0:
            return Int.MAX
        return len(self._storage)

    def ptr[origin: Origin, //](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    def grow(mut self, live: Int) where conforms_to(Self.T, Movable):
        var fresh = alloc(Layout[Self.T](length=max(1, self.capacity() * 2)))
        unsafe_uninit_move_n[overlapping=False](
            dest=fresh.unsafe_ptr(), src=self._storage.unsafe_ptr(), count=live
        )
        var old = self._storage^
        self._storage = fresh^
        Self._release(old^)

    @staticmethod
    def _release(var storage: Allocation[Self.T]):
        if len(storage) > 0:
            dealloc(storage^)
        else:
            _ = storage^.unsafe_leak()

    def release(deinit self):
        Self._release(self._storage^)
```

Excerpt from [code/09-implementing-list/raw_buffer.mojo](code/09-implementing-list/raw_buffer.mojo)

```mojo
struct Stack[T: Movable & Deinitable](Movable):
    var _buf: RawBuffer[Self.T]
    var _len: Int

    def __init__(out self):
        self._buf = RawBuffer[Self.T]()
        self._len = 0

    def push(mut self, var value: Self.T):
        if self._len == self._buf.capacity():
            self._buf.grow(self._len)
        self._buf.ptr().unsafe_offset(self._len).unsafe_write(value^)
        self._len += 1

    def pop(mut self) -> Self.T:
        self._len -= 1
        return self._buf.ptr().unsafe_offset(self._len).unsafe_take_pointee()

    def __deinit__(deinit self):
        unsafe_destroy_n(self._buf.ptr(), self._len)
        self._buf^.release()
```

Excerpt from [code/09-implementing-list/raw_buffer.mojo](code/09-implementing-list/raw_buffer.mojo)

`Stack` holds a linear field and is still `Deinitable`, because its
`__deinit__` consumes the field. A function that drops a `RawBuffer` without
releasing it does not compile, and the custom message from
`not Deinitable else "..."` says what to do:

```mojo
# EXPECT-ERROR: a RawBuffer that goes out of scope without release() is a compile error
# EXPECT-MATCH: abandoned without being explicitly destroyed: call release
# Claim: making the allocation owner linear moves "did someone free this?"
# from code review into the type checker.

from std.memory import Allocation, Layout, alloc, dealloc


struct RawBuffer[T: AnyType](
    Movable, not Deinitable else "call release() to free a RawBuffer"
):
    var _storage: Allocation[Self.T]

    def __init__(out self, capacity: Int):
        self._storage = alloc(Layout[Self.T](length=capacity))

    def release(deinit self):
        dealloc(self._storage^)


def checksum(packet_size: Int) -> Int:
    var scratch = RawBuffer[UInt8](packet_size)
    return packet_size % 251  # returns without releasing `scratch`


def main():
    print(checksum(1500))
```

[code/09-implementing-list/raw_buffer_unreleased_fails.mojo](code/09-implementing-list/raw_buffer_unreleased_fails.mojo)

## 9.9 Drain

*Rustonomicon counterpart: Implementing Vec, Drain.*

`drain(start, end)` removes a range and yields its elements by value. When
the drain dies, it closes the gap by relocating the tail down. The drain
borrows the list mutably for its whole life, and that borrow raises two
problems: leaking, and mutation through the list while the drain lives.

Leaking first. `forget_deinit` is a safe function: it consumes a value and
skips its destructor. Any type that relies on its destructor for soundness
breaks the moment someone forgets it. A drain that leaves the list's length
untouched and fixes it in `__deinit__` would leave the list claiming the
moved-out slots if someone forgot the drain, and the list would later destroy
or hand out moved-out values.

The fix is to make the list safe first and correct later. The constructor
shrinks the list's length to `start` before yielding anything:

```mojo
struct Drain[T: Movable & Deinitable, origin: MutOrigin](Iterator, Movable):
    comptime Element = Self.T
    var _list: Pointer[MyList[Self.T], Self.origin]
    var _next: Int
    var _end: Int
    var _tail_len: Int

    def __init__[
        list_origin: MutOrigin, //
    ](
        out self: Drain[Self.T, list_origin._get_owned_interior["element"]],
        ref[list_origin] list: MyList[Self.T],
        start: Int,
        end: Int,
    ):
        check_bounds(start, length=end + 1)
        check_bounds(end, length=len(list) + 1)
        self._list = Pointer(
            to=Pointer(to=list)._get_ref_with_unsafe_interior_origin[
                "element", list_origin
            ]()
        )
        self._next = start
        self._end = end
        self._tail_len = len(list) - end
        # Leak amplification: from here until the drain is destroyed, the
        # list claims only the prefix. Leaking the drain leaks the range and
        # the tail, but never exposes a moved-out slot.
        list._len = start

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.T:
        if self._next == self._end:
            raise StopIteration()
        self._next += 1
        return self._list[].unsafe_ptr().unsafe_offset(
            self._next - 1
        ).unsafe_take_pointee()

    def __deinit__(deinit self):
        var data = self._list[].unsafe_ptr().unsafe_origin_cast[
            MutUntrackedOrigin
        ]()
        unsafe_destroy_n(data.unsafe_offset(self._next), self._end - self._next)
        var start = self._list[]._len
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(start),
            src=data.unsafe_offset(self._end),
            count=self._tail_len,
        )
        self._list[]._len = start + self._tail_len
```

Excerpt from [code/09-implementing-list/drain.mojo](code/09-implementing-list/drain.mojo)

While the drain lives, the list claims only the prefix. If the drain dies
normally, its destructor destroys the unyielded part of the range, shifts the
tail down, and restores the length. If someone leaks it, the range and the
tail leak with it, and the list stays valid with only its prefix. Leaking
more than strictly necessary keeps every reachable value valid.

```mojo
def main() raises:
    var drops = ArcPointer(0)

    var parts = tracked_list(5, drops)
    var drained = List[Int]()
    for part in parts.drain(1, 3):
        drained.append(part.id)
    assert_equal(drained, [1, 2])
    assert_equal(len(parts), 3)
    assert_equal(parts[1].id, 3)  # the tail moved down

    drops[] = 0
    var partial = tracked_list(5, drops)
    var drain = partial.drain(0, 4)
    assert_equal(next(drain).id, 0)
    _ = drain^
    assert_equal(drops[], 4)  # one yielded, three destroyed by the drain
    assert_equal(len(partial), 1)

    drops[] = 0
    var leaky = tracked_list(5, drops)
    var leaked = leaky.drain(1, 2)
    forget_deinit(leaked^)
    assert_equal(drops[], 0)  # nothing destroyed by the leaked drain
    assert_equal(len(leaky), 1)  # only the prefix remains reachable
    assert_equal(leaky[0].id, 0)
    # `leaky` died after its last use: one destructor ran, four elements
    # leaked for good.
    assert_equal(drops[], 1)
```

Excerpt from [code/09-implementing-list/drain.mojo](code/09-implementing-list/drain.mojo)

Now mutation. The drain stores a pointer to the list. If that pointer carried
the list's ordinary origin, a `push` while the drain is alive would compile,
reallocate the buffer, and leave the drain pointing into freed memory. The
constructor instead types the pointer with the list's interior origin, by
taking the reference through `_get_ref_with_unsafe_interior_origin`. Any
mutation of the list now invalidates the drain:

```mojo
# EXPECT-ERROR: pushing onto a list while a drain over it is still in use invalidates the drain
# EXPECT-MATCH: use of invalidated interior reference
# Claim: the drain borrows the list through an interior origin, so a push
# (which may reallocate) invalidates the drain, and using it afterward fails.

from std.collections import check_bounds
from std.memory import (
    ArcPointer,
    Allocation,
    Layout,
    ThinAllocation,
    alloc,
    dealloc,
    forget_deinit,
    unsafe_destroy_n,
    unsafe_uninit_move_n,
)
from std.sys import size_of
from std.testing import assert_equal, assert_true


# ===--- RawBuffer: owns the allocation, knows nothing about elements ---=== #


struct RawBuffer[T: AnyType](Movable, not Deinitable):
    var _storage: Allocation[Self.T]

    def __init__(out self):
        # Capacity 0 never touches the allocator: a dangling, well-aligned
        # pointer stands in for storage.
        self._storage = ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))

    def capacity(self) -> Int:
        comptime if size_of[Self.T]() == 0:
            return Int.MAX  # zero-sized elements fit anywhere
        return len(self._storage)

    def ptr[origin: Origin, //](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    def grow(mut self, live: Int) where conforms_to(Self.T, Movable):
        var new_capacity = max(1, self.capacity() * 2)
        var fresh = alloc(Layout[Self.T](length=new_capacity))
        unsafe_uninit_move_n[overlapping=False](
            dest=fresh.unsafe_ptr(), src=self._storage.unsafe_ptr(), count=live
        )
        var old = self._storage^
        self._storage = fresh^
        Self._release(old^)

    @staticmethod
    def _release(var storage: Allocation[Self.T]):
        if len(storage) > 0:
            dealloc(storage^)
        else:
            # The dangling placeholder never came from the allocator.
            _ = storage^.unsafe_leak()

    def release(deinit self):
        Self._release(self._storage^)


# ===--- MyList: tracks which slots hold live elements ---=== #


struct MyList[T: AnyType](
    Movable,
    Sized,
    Deinitable where conforms_to(T, Deinitable) else (
        "a MyList of non-Deinitable elements needs an explicit"
        " deinit_with() call"
    ),
):
    var _buf: RawBuffer[Self.T]
    var _len: Int

    # Experimental: element references live in an interior origin, so any
    # mutation of the list invalidates them.
    comptime _Elements[origin: Origin] = origin._get_owned_interior["element"]

    def __init__(out self):
        self._buf = RawBuffer[Self.T]()
        self._len = 0

    def __len__(self) -> Int:
        return self._len

    def capacity(self) -> Int:
        return self._buf.capacity()

    def unsafe_ptr[
        origin: Origin, //
    ](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._buf.ptr().unsafe_origin_cast[origin]()

    def push(mut self, var value: Self.T) where conforms_to(Self.T, Movable):
        if self._len == self.capacity():
            self._buf.grow(self._len)
        self._buf.ptr().unsafe_offset(self._len).unsafe_write(value^)
        self._len += 1

    def pop(mut self) -> Optional[Self.T] where conforms_to(Self.T, Movable):
        if self._len == 0:
            return None
        self._len -= 1
        return self._buf.ptr().unsafe_offset(self._len).unsafe_take_pointee()

    @__unsafe_nested_origins_read_only
    def __getitem__(
        ref self, index: Int
    ) -> ref[Self._Elements[origin_of(self)]] Self.T:
        check_bounds(index, length=self._len)
        return self.unsafe_ptr().unsafe_offset(
            index
        )._get_ref_with_unsafe_interior_origin["element", origin_of(self)]()

    def as_span(ref self) -> Span[Self.T, origin_of(self)]:
        return Span(unsafe_ptr=self.unsafe_ptr(), length=self._len)

    def insert(
        mut self, index: Int, var value: Self.T
    ) where conforms_to(Self.T, Movable):
        check_bounds(index, length=self._len + 1)
        if self._len == self.capacity():
            self._buf.grow(self._len)
        var data = self.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(index + 1),
            src=data.unsafe_offset(index),
            count=self._len - index,
        )
        data.unsafe_offset(index).unsafe_write(value^)
        self._len += 1

    def remove(mut self, index: Int) -> Self.T where conforms_to(Self.T, Movable):
        check_bounds(index, length=self._len)
        var data = self.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
        var removed = data.unsafe_offset(index).unsafe_take_pointee()
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(index),
            src=data.unsafe_offset(index + 1),
            count=self._len - index - 1,
        )
        self._len -= 1
        return removed^

    def drain(
        mut self, start: Int, end: Int
    ) -> Drain[Self.T, Self._Elements[origin_of(self)]] where conforms_to(
        Self.T, Movable & Deinitable
    ):
        return Drain(self, start, end)

    def __iter__(
        var self,
    ) -> IntoIter[Self.T] where conforms_to(Self.T, Movable & Deinitable):
        return IntoIter(self^)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        unsafe_destroy_n(self._buf.ptr(), self._len)
        self._buf^.release()

    def deinit_with(deinit self, deinit_func: Some[def(var Self.T)], /):
        var data = self._buf.ptr()
        for index in range(self._len):
            data.unsafe_offset(index).unsafe_deinit_pointee_with(deinit_func)
        self._buf^.release()


# ===--- IntoIter: owns the list, yields elements by value ---=== #


struct IntoIter[T: Movable & Deinitable](Iterator, Movable):
    comptime Element = Self.T
    var _list: MyList[Self.T]
    var _next: Int

    def __init__(out self, var list: MyList[Self.T]):
        self._list = list^
        self._next = 0

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.T:
        if self._next == len(self._list):
            raise StopIteration()
        self._next += 1
        return self._list.unsafe_ptr().unsafe_offset(
            self._next - 1
        ).unsafe_take_pointee()

    def __deinit__(deinit self):
        # Slots before _next already moved out; destroy only the rest, then
        # tell the list it holds nothing so its own destructor skips them.
        var data = self._list.unsafe_ptr()
        unsafe_destroy_n(
            data.unsafe_offset(self._next), len(self._list) - self._next
        )
        self._list._len = 0


# ===--- Drain: removes a range, closes the gap when destroyed ---=== #


struct Drain[T: Movable & Deinitable, origin: MutOrigin](Iterator, Movable):
    comptime Element = Self.T
    var _list: Pointer[MyList[Self.T], Self.origin]
    var _next: Int
    var _end: Int
    var _tail_len: Int

    def __init__[
        list_origin: MutOrigin, //
    ](
        out self: Drain[Self.T, list_origin._get_owned_interior["element"]],
        ref[list_origin] list: MyList[Self.T],
        start: Int,
        end: Int,
    ):
        check_bounds(start, length=end + 1)
        check_bounds(end, length=len(list) + 1)
        self._list = Pointer(
            to=Pointer(to=list)._get_ref_with_unsafe_interior_origin[
                "element", list_origin
            ]()
        )
        self._next = start
        self._end = end
        self._tail_len = len(list) - end
        # Leak amplification: from here until the drain is destroyed, the
        # list claims only the prefix. Leaking the drain leaks the range and
        # the tail, but never exposes a moved-out slot.
        list._len = start

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.T:
        if self._next == self._end:
            raise StopIteration()
        self._next += 1
        return self._list[].unsafe_ptr().unsafe_offset(
            self._next - 1
        ).unsafe_take_pointee()

    def __deinit__(deinit self):
        var data = self._list[].unsafe_ptr().unsafe_origin_cast[
            MutUntrackedOrigin
        ]()
        unsafe_destroy_n(data.unsafe_offset(self._next), self._end - self._next)
        var start = self._list[]._len
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(start),
            src=data.unsafe_offset(self._end),
            count=self._tail_len,
        )
        self._list[]._len = start + self._tail_len


struct Tracked(Movable):
    """An element that counts its own destructions in a shared counter."""

    var id: Int
    var drops: ArcPointer[Int]

    def __init__(out self, id: Int, drops: ArcPointer[Int]):
        self.id = id
        self.drops = drops

    def __deinit__(deinit self):
        self.drops[] += 1


def main() raises:
    var drops = ArcPointer(0)
    var parts = MyList[Tracked]()
    for id in range(5):
        parts.push(Tracked(id, drops))
    var drain = parts.drain(0, 4)
    _ = next(drain)
    parts.push(Tracked(9, drops))
    _ = drain^
```

[code/09-implementing-list/drain_invalidated_fails.mojo](code/09-implementing-list/drain_invalidated_fails.mojo)

ASAP destruction makes the rule less strict in practice than it reads. If
the code never touches the drain after the `push`, the drain's last use comes
before the `push`, its destructor runs there, and the program compiles and
behaves.

The constructor's `out self` names the result type explicitly,
`Drain[Self.T, list_origin._get_owned_interior["element"]]`, because the
compiler can't infer an interior origin from an argument. `MyList.drain` then
constructs it with a plain `Drain(self, start, end)`.

## 9.10 Handling zero-sized types

*Rustonomicon counterpart: Implementing Vec, Handling Zero-Sized Types.*

A struct with no fields has size zero. `alloc()` checks for that at compile
time and returns a dangling, well-aligned sentinel without calling the
allocator, and `dealloc()` of a zero-sized allocation does nothing. Offsetting
a pointer to a zero-sized type leaves the address unchanged, since every
element sits at the same place.

```mojo
# Claims:
# - A struct with no fields has size 0.
# - alloc() of a zero-sized type returns a dangling, well-aligned sentinel
#   without calling the allocator, and dealloc() of it is a no-op.
# - Offsetting a pointer to a zero-sized type does not move it.
# (mylist_final.mojo tests that MyList never allocates for these elements.)

from std.memory import Layout, alloc, dealloc
from std.sys import size_of
from std.testing import assert_equal, assert_true


struct Visited(Movable):
    """A zero-sized marker: its type carries all its information."""

    def __init__(out self):
        pass


def main() raises:
    assert_equal(size_of[Visited](), 0)

    var markers = alloc(Layout[Visited](length=1000))
    var base = markers.unsafe_ptr()
    var dangling = Pointer[Visited, MutUntrackedOrigin].unsafe_dangling()
    var base_address = Int(base)
    var last_address = Int(base.unsafe_offset(999))
    dealloc(markers^)

    assert_equal(base_address, Int(dangling))
    assert_equal(last_address, base_address)
```

[code/09-implementing-list/zero_sized_types.mojo](code/09-implementing-list/zero_sized_types.mojo)

`MyList` needs one change for zero-sized elements. Without it, the list would
double its capacity (and run the growth logic) on every power of two even
though no memory exists to grow. `RawBuffer.capacity()` reports `Int.MAX`
for zero-sized `T`, so `push` never grows, and the dangling placeholder from
`RawBuffer()` serves forever:

```mojo
    def capacity(self) -> Int:
        comptime if size_of[Self.T]() == 0:
            return Int.MAX
        return len(self._storage)
```

Excerpt from [code/09-implementing-list/raw_buffer.mojo](code/09-implementing-list/raw_buffer.mojo)

Writing a zero-sized value through the dangling pointer writes zero bytes,
and taking one out reads zero bytes, so `push` and `pop` work unchanged.

Pointer arithmetic that divides by the element size has no answer.
`offset_from` checks the size at compile time:

```mojo
# EXPECT-ERROR: offset_from rejects zero-sized pointee types at compile time, because every element sits at the same address
# EXPECT-MATCH: non-zero-sized pointee
# Claim: element distance is byte distance divided by size_of[T](), which
# has no meaning when the size is zero, so the call fails to compile.

from std.memory import Layout, alloc, dealloc


struct Visited(Movable):
    def __init__(out self):
        pass


def main():
    var markers = alloc(Layout[Visited](length=10))
    var base = markers.unsafe_ptr()
    print(base.unsafe_offset(3).offset_from(base))
    dealloc(markers^)
```

[code/09-implementing-list/zst_offset_from_fails.mojo](code/09-implementing-list/zst_offset_from_fails.mojo)

## 9.11 Final code

*Rustonomicon counterpart: Implementing Vec, Final Code.*

The complete list, built on `RawBuffer`, with `IntoIter`, `Drain`, and a test
suite that checks every claim in this chapter by counting destructor calls.

```mojo
# The complete MyList[T]: a growable array built on a linear RawBuffer.
# Claims proven by the tests below:
# - push and pop move values in and out; pop runs no destructor.
# - Growth doubles capacity (1, 2, 4, 8) and an empty list never allocates.
# - insert and remove shift elements by relocation, so no destructor runs
#   for the shifted elements.
# - Dropping the list destroys exactly the live elements, once each.
# - An owned iterator destroys the elements it never yielded.
# - A drain removes a range and closes the gap; a leaked drain leaks elements
#   but leaves the list valid.
# - Zero-sized elements never allocate.
# - A list of non-Deinitable elements is destroyed with deinit_with().

from std.collections import check_bounds
from std.memory import (
    ArcPointer,
    Allocation,
    Layout,
    ThinAllocation,
    alloc,
    dealloc,
    forget_deinit,
    unsafe_destroy_n,
    unsafe_uninit_move_n,
)
from std.sys import size_of
from std.testing import assert_equal, assert_false, assert_true, TestSuite


# ===--- RawBuffer: owns the allocation, knows nothing about elements ---=== #


struct RawBuffer[T: AnyType](Movable, not Deinitable):
    var _storage: Allocation[Self.T]

    def __init__(out self):
        # Capacity 0 never touches the allocator: a dangling, well-aligned
        # pointer stands in for storage.
        self._storage = ThinAllocation(
            unsafe_owned_ptr=Pointer[
                Self.T, MutUntrackedOrigin
            ].unsafe_dangling()
        ).unsafe_with_layout(Layout[Self.T](length=0))

    def capacity(self) -> Int:
        comptime if size_of[Self.T]() == 0:
            return Int.MAX  # zero-sized elements fit anywhere
        return len(self._storage)

    def ptr[origin: Origin, //](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._storage.unsafe_ptr().unsafe_origin_cast[origin]()

    def grow(mut self, live: Int) where conforms_to(Self.T, Movable):
        var new_capacity = max(1, self.capacity() * 2)
        var fresh = alloc(Layout[Self.T](length=new_capacity))
        unsafe_uninit_move_n[overlapping=False](
            dest=fresh.unsafe_ptr(), src=self._storage.unsafe_ptr(), count=live
        )
        var old = self._storage^
        self._storage = fresh^
        Self._release(old^)

    @staticmethod
    def _release(var storage: Allocation[Self.T]):
        if len(storage) > 0:
            dealloc(storage^)
        else:
            # The dangling placeholder never came from the allocator.
            _ = storage^.unsafe_leak()

    def release(deinit self):
        Self._release(self._storage^)


# ===--- MyList: tracks which slots hold live elements ---=== #


struct MyList[T: AnyType](
    Movable,
    Sized,
    Deinitable where conforms_to(T, Deinitable) else (
        "a MyList of non-Deinitable elements needs an explicit"
        " deinit_with() call"
    ),
):
    var _buf: RawBuffer[Self.T]
    var _len: Int

    # Experimental: element references live in an interior origin, so any
    # mutation of the list invalidates them.
    comptime _Elements[origin: Origin] = origin._get_owned_interior["element"]

    def __init__(out self):
        self._buf = RawBuffer[Self.T]()
        self._len = 0

    def __len__(self) -> Int:
        return self._len

    def capacity(self) -> Int:
        return self._buf.capacity()

    def unsafe_ptr[
        origin: Origin, //
    ](ref[origin] self) -> Pointer[Self.T, origin]:
        return self._buf.ptr().unsafe_origin_cast[origin]()

    def push(mut self, var value: Self.T) where conforms_to(Self.T, Movable):
        if self._len == self.capacity():
            self._buf.grow(self._len)
        self._buf.ptr().unsafe_offset(self._len).unsafe_write(value^)
        self._len += 1

    def pop(mut self) -> Optional[Self.T] where conforms_to(Self.T, Movable):
        if self._len == 0:
            return None
        self._len -= 1
        return self._buf.ptr().unsafe_offset(self._len).unsafe_take_pointee()

    @__unsafe_nested_origins_read_only
    def __getitem__(
        ref self, index: Int
    ) -> ref[Self._Elements[origin_of(self)]] Self.T:
        check_bounds(index, length=self._len)
        return self.unsafe_ptr().unsafe_offset(
            index
        )._get_ref_with_unsafe_interior_origin["element", origin_of(self)]()

    def as_span(ref self) -> Span[Self.T, origin_of(self)]:
        return Span(unsafe_ptr=self.unsafe_ptr(), length=self._len)

    def insert(
        mut self, index: Int, var value: Self.T
    ) where conforms_to(Self.T, Movable):
        check_bounds(index, length=self._len + 1)
        if self._len == self.capacity():
            self._buf.grow(self._len)
        var data = self.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(index + 1),
            src=data.unsafe_offset(index),
            count=self._len - index,
        )
        data.unsafe_offset(index).unsafe_write(value^)
        self._len += 1

    def remove(mut self, index: Int) -> Self.T where conforms_to(Self.T, Movable):
        check_bounds(index, length=self._len)
        var data = self.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
        var removed = data.unsafe_offset(index).unsafe_take_pointee()
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(index),
            src=data.unsafe_offset(index + 1),
            count=self._len - index - 1,
        )
        self._len -= 1
        return removed^

    def drain(
        mut self, start: Int, end: Int
    ) -> Drain[Self.T, Self._Elements[origin_of(self)]] where conforms_to(
        Self.T, Movable & Deinitable
    ):
        return Drain(self, start, end)

    def __iter__(
        var self,
    ) -> IntoIter[Self.T] where conforms_to(Self.T, Movable & Deinitable):
        return IntoIter(self^)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        unsafe_destroy_n(self._buf.ptr(), self._len)
        self._buf^.release()

    def deinit_with(deinit self, deinit_func: Some[def(var Self.T)], /):
        var data = self._buf.ptr()
        for index in range(self._len):
            data.unsafe_offset(index).unsafe_deinit_pointee_with(deinit_func)
        self._buf^.release()


# ===--- IntoIter: owns the list, yields elements by value ---=== #


struct IntoIter[T: Movable & Deinitable](Iterator, Movable):
    comptime Element = Self.T
    var _list: MyList[Self.T]
    var _next: Int

    def __init__(out self, var list: MyList[Self.T]):
        self._list = list^
        self._next = 0

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.T:
        if self._next == len(self._list):
            raise StopIteration()
        self._next += 1
        return self._list.unsafe_ptr().unsafe_offset(
            self._next - 1
        ).unsafe_take_pointee()

    def __deinit__(deinit self):
        # Slots before _next already moved out; destroy only the rest, then
        # tell the list it holds nothing so its own destructor skips them.
        var data = self._list.unsafe_ptr()
        unsafe_destroy_n(
            data.unsafe_offset(self._next), len(self._list) - self._next
        )
        self._list._len = 0


# ===--- Drain: removes a range, closes the gap when destroyed ---=== #


struct Drain[T: Movable & Deinitable, origin: MutOrigin](Iterator, Movable):
    comptime Element = Self.T
    var _list: Pointer[MyList[Self.T], Self.origin]
    var _next: Int
    var _end: Int
    var _tail_len: Int

    def __init__[
        list_origin: MutOrigin, //
    ](
        out self: Drain[Self.T, list_origin._get_owned_interior["element"]],
        ref[list_origin] list: MyList[Self.T],
        start: Int,
        end: Int,
    ):
        check_bounds(start, length=end + 1)
        check_bounds(end, length=len(list) + 1)
        self._list = Pointer(
            to=Pointer(to=list)._get_ref_with_unsafe_interior_origin[
                "element", list_origin
            ]()
        )
        self._next = start
        self._end = end
        self._tail_len = len(list) - end
        # Leak amplification: from here until the drain is destroyed, the
        # list claims only the prefix. Leaking the drain leaks the range and
        # the tail, but never exposes a moved-out slot.
        list._len = start

    def __iter__(var self) -> Self:
        return self^

    def __next__(mut self) raises StopIteration -> Self.T:
        if self._next == self._end:
            raise StopIteration()
        self._next += 1
        return self._list[].unsafe_ptr().unsafe_offset(
            self._next - 1
        ).unsafe_take_pointee()

    def __deinit__(deinit self):
        var data = self._list[].unsafe_ptr().unsafe_origin_cast[
            MutUntrackedOrigin
        ]()
        unsafe_destroy_n(data.unsafe_offset(self._next), self._end - self._next)
        var start = self._list[]._len
        unsafe_uninit_move_n[overlapping=True](
            dest=data.unsafe_offset(start),
            src=data.unsafe_offset(self._end),
            count=self._tail_len,
        )
        self._list[]._len = start + self._tail_len


# ===--- Test support ---=== #


struct Tracked(Movable):
    """An element that counts its own destructions in a shared counter."""

    var id: Int
    var drops: ArcPointer[Int]

    def __init__(out self, id: Int, drops: ArcPointer[Int]):
        self.id = id
        self.drops = drops

    def __deinit__(deinit self):
        self.drops[] += 1


def tracked_list(count: Int, drops: ArcPointer[Int]) -> MyList[Tracked]:
    var parts = MyList[Tracked]()
    for id in range(count):
        parts.push(Tracked(id, drops))
    return parts^


struct Ticket(Movable, not Deinitable):
    var seat: Int

    def __init__(out self, seat: Int):
        self.seat = seat

    def redeem(deinit self) -> Int:
        return self.seat


struct Marker(Movable):
    def __init__(out self):
        pass


# ===--- Tests ---=== #


def test_push_and_pop() raises:
    var drops = ArcPointer(0)
    var parts = tracked_list(3, drops)
    var last = parts.pop()
    assert_equal(drops[], 0)  # pop moved the value out; nothing destroyed
    assert_equal(last.value().id, 2)
    # That was the last use of `last`, so its destructor already ran.
    assert_equal(drops[], 1)
    assert_equal(len(parts), 2)


def test_growth_doubles() raises:
    var cities = MyList[String]()
    assert_equal(cities.capacity(), 0)
    var seen = List[Int]()
    for city in ["Oslo", "Lima", "Pune", "Kyiv", "Graz"]:
        cities.push(city)
        seen.append(cities.capacity())
    assert_equal(seen, [1, 2, 4, 4, 8])


def test_index_and_span() raises:
    var readings = MyList[Float64]()
    for celsius in [21.5, 22.0, 23.25]:
        readings.push(celsius)
    readings[1] = 22.75
    var total = 0.0
    for reading in readings.as_span():
        total += reading
    assert_equal(total, 67.5)


def test_insert_and_remove_relocate() raises:
    var drops = ArcPointer(0)
    var parts = tracked_list(4, drops)
    parts.insert(1, Tracked(40, drops))
    assert_equal(parts[1].id, 40)
    assert_equal(parts[2].id, 1)
    var removed = parts.remove(0)
    assert_equal(parts[0].id, 40)
    assert_equal(len(parts), 4)
    assert_equal(drops[], 0)  # shifting ran no destructors
    assert_equal(removed.id, 0)
    deinit(parts^)  # destroy the list here, not at its last use above
    assert_equal(drops[], 5)


def test_drop_destroys_live_elements_once() raises:
    var drops = ArcPointer(0)
    var parts = tracked_list(6, drops)
    _ = parts.pop()
    assert_equal(drops[], 1)
    _ = parts^
    assert_equal(drops[], 6)


def test_into_iter_destroys_unyielded_tail() raises:
    var drops = ArcPointer(0)
    var parts = tracked_list(5, drops)
    var yielded = 0
    for part in parts^:
        yielded += 1
        if part.id == 1:
            break
    assert_equal(yielded, 2)
    assert_equal(drops[], 5)


def test_drain_closes_gap() raises:
    var drops = ArcPointer(0)
    var parts = tracked_list(5, drops)
    var drained = List[Int]()
    for part in parts.drain(1, 3):
        drained.append(part.id)
    assert_equal(drained, [1, 2])
    assert_equal(drops[], 2)  # each drained element died after its iteration
    assert_equal(len(parts), 3)
    assert_equal(parts[1].id, 3)


def test_partial_drain_destroys_rest() raises:
    var drops = ArcPointer(0)
    var parts = tracked_list(5, drops)
    var drain = parts.drain(0, 4)
    assert_equal(next(drain).id, 0)
    assert_equal(drops[], 1)  # the yielded temporary already died
    _ = drain^
    assert_equal(drops[], 4)  # the drain destroyed ids 1, 2, and 3
    assert_equal(len(parts), 1)
    assert_equal(parts[0].id, 4)


def test_leaked_drain_leaves_list_valid() raises:
    var drops = ArcPointer(0)
    var parts = tracked_list(5, drops)
    var drain = parts.drain(1, 2)
    forget_deinit(drain^)
    assert_equal(len(parts), 1)  # only the prefix survives
    assert_equal(parts[0].id, 0)
    assert_equal(drops[], 0)  # four elements leaked, none destroyed twice
    _ = parts^
    assert_equal(drops[], 1)


def test_zero_sized_elements_never_allocate() raises:
    var markers = MyList[Marker]()
    for _ in range(1000):
        markers.push(Marker())
    assert_equal(len(markers), 1000)
    assert_equal(markers.capacity(), Int.MAX)
    assert_true(markers.pop())


def test_non_deinitable_elements() raises:
    var tickets = MyList[Ticket]()
    tickets.push(Ticket(12))
    tickets.push(Ticket(14))
    var redeemed = 0

    def redeem(var ticket: Ticket) {mut redeemed}:
        redeemed += ticket^.redeem()

    tickets^.deinit_with(redeem)
    assert_equal(redeemed, 26)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
```

[code/09-implementing-list/mylist_final.mojo](code/09-implementing-list/mylist_final.mojo)

Several tests order their assertions around ASAP destruction. A value dies
after its last use, not at the end of its scope, so a destructor count read
after a value's last use already includes that value. Three tactics keep the
counts honest:

1. Assert the count before the value's last use, then again after it.
2. Read the value at the point where you want it to die.
3. Call `deinit(value^)` to destroy it on a line you choose.
