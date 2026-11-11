# 3. Ownership

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/origin/__init__.mojo, Mojo/stdlib/std/memory/pointer.mojo, Mojo/stdlib/std/memory/alloc.mojo, Mojo/stdlib/std/collections/span.mojo, Mojo/stdlib/std/collections/list.mojo, Mojo/stdlib/std/traits/anytype.mojo, Mojo/stdlib/std/traits/deinitable.mojo, Mojo/stdlib/std/builtin/swap.mojo -->

References, exclusivity, origins, ASAP destruction, and the places where the checker's view of memory and the machine's view part ways.

Every value in Mojo has exactly one owner, a `var` binding or a field. Every
reference to that value carries an *origin*: a compile-time name for the
storage it borrows from, plus whether the borrow can mutate. The compiler uses
origins for three jobs:

1. It refuses a use of a value after that value moved away or died.
2. It refuses a call that hands one value to a `mut` argument and to any other
   argument at the same time (argument exclusivity).
3. It decides when each value dies. Mojo destroys a value right after its last
   use, not at the end of its scope, and a live reference counts as a use of
   its owner.

The third job surprises people most, and it shapes every section below. Safe
code never observes it as a hazard, because a reference keeps its owner alive.
Unsafe code observes it constantly, because the moment a pointer stops carrying
a tracked origin, its owner can die under it.

Several samples in this chapter record events into a `List[String]` and assert
the order. The recorder type, `Probe`, holds a pointer to that log and appends
a line from its `__deinit__`. Samples that print instead state the printed
order in their header comment.

## 3.1 References

*Rustonomicon counterpart: References.*

Mojo has three ways to refer to a value without owning it:

- Argument conventions. `imm` (the default) reads the caller's value in place,
  `mut` writes it in place, and `ref` takes either and infers which.
- `ref` bindings. `ref tag = crate` names an existing value. The binding owns
  nothing and never reseats: assigning to `tag` assigns to `crate`.
- `Pointer[T, origin]`. A first-class, copyable value. Constructing one with
  `Pointer(to=value)` and dereferencing it with `[]` are safe operations; the
  `unsafe_`-prefixed methods (offsetting, writing uninitialized memory, casting
  origins) are where the safety contract moves to you.

A `ref` binding behaves as the value it names, in every position:

```mojo
# Claims (3.1):
# - A `ref` binding names an existing value; writes through it change the original.
# - Assigning to a `ref` binding assigns to the referent. It never reseats the binding.
# - An `imm` argument reads the caller's value in place; a `mut` argument writes it.
# - A `ref` argument accepts mutable bindings and immutable values alike.
from std.testing import assert_equal


def label_width(imm label: String) -> Int:
    return label.byte_length()


def stamp(mut label: String):
    label += "#1"


def measured(ref label: String) -> Int:
    return label.byte_length()


def main() raises:
    var crate = String("crate")
    assert_equal(label_width(crate), 5)

    stamp(crate)
    assert_equal(crate, "crate#1")
    assert_equal(measured(crate), 7)
    assert_equal(measured("pallet"), 6)

    ref tag = crate
    tag += "b"
    assert_equal(crate, "crate#1b")

    var spare = String("spare")
    tag = spare  # copies `spare` into `crate`; `tag` still names `crate`
    spare += "-edited"
    assert_equal(crate, "spare")
    assert_equal(spare, "spare-edited")
```

[code/03-ownership/ref_binding_writes_through.mojo](code/03-ownership/ref_binding_writes_through.mojo)

The default `imm` convention gives the callee a read-only view. Writing to it
fails to compile:

```mojo
# EXPECT-ERROR: an imm (default) argument is read-only inside the callee
# EXPECT-MATCH: must be mutable
# Claim (3.1): the default argument convention is `imm`; writing to it is a compile error.


def stamp(label: String):
    label += "#1"


def main():
    var crate = String("crate")
    stamp(crate)
```

[code/03-ownership/imm_argument_rejects_write_fails.mojo](code/03-ownership/imm_argument_rejects_write_fails.mojo)

### A pointer's origin is part of its type

`Pointer(to=primary)` has the type `Pointer[String, origin_of(primary)]`. A
pointer to `spare` has a different type, so you cannot reseat one into the
other:

```mojo
# EXPECT-ERROR: a Pointer's origin is part of its type, so it cannot reseat to another owner
# EXPECT-MATCH: cannot implicitly convert
# Claim (3.1): `Pointer(to=primary)` has type `Pointer[String, origin_of(primary)]`;
# assigning a pointer to a different value changes the type.


def main():
    var primary = String("lane-a")
    var spare = String("lane-b")
    var cursor = Pointer(to=primary)
    cursor = Pointer(to=spare)
    print(cursor[])
```

[code/03-ownership/pointer_origin_fixed_at_type_fails.mojo](code/03-ownership/pointer_origin_fixed_at_type_fails.mojo)

When a pointer needs to range over several owners, declare the union of their
origins up front. The union keeps every member alive and stays mutable because
every member is mutable:

```mojo
# Claims (3.1):
# - A Pointer declared with a union origin can point at any member of the union.
# - The union origin is mutable when every member is mutable, so writes work.
from std.testing import assert_equal


def main() raises:
    var primary = String("lane-a")
    var spare = String("lane-b")
    var cursor: Pointer[String, origin_of(primary, spare)] = Pointer(to=primary)
    assert_equal(cursor[], "lane-a")

    cursor = Pointer(to=spare)
    cursor[] += "!"
    assert_equal(spare, "lane-b!")
    assert_equal(primary, "lane-a")
```

[code/03-ownership/pointer_union_origin_reseats.mojo](code/03-ownership/pointer_union_origin_reseats.mojo)

### References keep their owners alive

A reference to a value counts as a use of that value. Two consequences follow.
First, moving the owner away while a reference still has uses ahead of it fails
to compile, because the owner no longer holds a value:

```mojo
# EXPECT-ERROR: transferring a value out while a pointer to it is still used
# EXPECT-MATCH: use of uninitialized value 'city'
# Claim (3.1): a live Pointer counts as a use of its owner. After `city^`
# the owner holds no value, so the later dereference reads an uninitialized value.


def main():
    var city = String("Lisbon")
    var cursor = Pointer(to=city)
    var moved = city^
    print(cursor[], moved)
```

[code/03-ownership/reference_blocks_transfer_fails.mojo](code/03-ownership/reference_blocks_transfer_fails.mojo)

Second, the owner's destruction waits for the reference's last use, while
values nobody refers to die at once:

```mojo
# Claims (3.1, 3.9):
# - A value without later uses dies immediately (ASAP destruction).
# - A live Pointer keeps its owner alive until the pointer's last use.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


def main() raises:
    var log = List[String]()
    var sensor = Probe("sensor", log)
    var cursor = Pointer(to=sensor)
    log.append("pointer made")
    _ = Probe("unused", log)
    log.append("read " + cursor[].label)
    log.append("end")
    assert_equal(
        log,
        [
            "pointer made",
            "deinit unused",
            "deinit sensor",
            "read sensor",
            "end",
        ],
    )
```

[code/03-ownership/reference_extends_owner_life.mojo](code/03-ownership/reference_extends_owner_life.mojo)

Read the log closely. `"deinit sensor"` lands before `"read sensor"`. The
expression `"read " + cursor[].label` produces a new `String`, and that
expression is the last use of `cursor`, so `sensor` dies before `log.append`
runs. Destruction happens between subexpressions, not at statement
boundaries.

A `ref` binding can also hold a function result. The compiler materializes the
temporary and keeps it alive for the binding's uses:

```mojo
# Claim (3.1): a `ref` binding to a function result materializes the temporary
# and keeps it alive (and mutable) for every use of the binding.
from std.testing import assert_equal


def pallet_label() -> String:
    return "pallet"


def main() raises:
    ref label = pallet_label()
    label += "-7"
    assert_equal(label, "pallet-7")
```

[code/03-ownership/ref_binding_to_temporary.mojo](code/03-ownership/ref_binding_to_temporary.mojo)

## 3.2 Aliasing

*Rustonomicon counterpart: Aliasing.*

Mojo's aliasing rule is *argument exclusivity*: if a call passes a value to a
`mut` argument, no other argument of that call may refer to the same value,
mutably or immutably. The compiler checks this at each call site, using
origins. It lets a callee assume that writes through a `mut` argument never
show up through its other arguments, which is both a correctness guarantee and
an optimization license.

```mojo
# EXPECT-ERROR: one value passed both mutably and immutably to the same call
# EXPECT-MATCH: aliasing values passed mutably to 'journal'.*immutably to 'entry'
# Claim (3.2): a `mut` argument may not alias any other argument of the same call.


def append_twice(mut journal: String, entry: String):
    journal += entry
    journal += entry


def main():
    var journal = String("boot;")
    append_twice(journal, journal)
    print(journal)
```

[code/03-ownership/exclusivity_mut_and_imm_fails.mojo](code/03-ownership/exclusivity_mut_and_imm_fails.mojo)

```mojo
# EXPECT-ERROR: one value passed to two mut arguments of the same call
# EXPECT-MATCH: aliasing values passed mutably to 'lhs'.*mutably to 'rhs'
# Claim (3.2): two `mut` arguments may not alias each other.


def main():
    var route = String("A7")
    swap(route, route)
    print(route)
```

[code/03-ownership/exclusivity_two_mut_fails.mojo](code/03-ownership/exclusivity_two_mut_fails.mojo)

### Element granularity

The checker reasons about origins, not addresses. Every element of a `List`
shares one interior origin, so two different elements look identical to it:

```mojo
# EXPECT-ERROR: two elements of one List passed to two mut arguments
# EXPECT-MATCH: temps\["element"\]
# Claim (3.2): every element of a List shares one interior origin, so the checker
# cannot tell `temps[0]` from `temps[1]` and rejects the call.


def main():
    var temps: List[Int] = [12, 18, 25]
    swap(temps[0], temps[1])
    print(temps)
```

[code/03-ownership/exclusivity_list_elements_fails.mojo](code/03-ownership/exclusivity_list_elements_fails.mojo)

Section 3.11 covers the ways around this.

### References embedded in values

Exclusivity follows references stored inside values. A `Span` carries the
origin of the `List` it views, so passing a mutable `Span(cells)` next to
`cells` itself aliases:

```mojo
# EXPECT-ERROR: a mutable Span and its List passed to the same call
# EXPECT-MATCH: aliasing values passed mutably to 'dest'.*immutably to 'src'
# Claim (3.2): exclusivity checking sees references embedded inside values. A
# `Span` carries the List's origin, so `Span(cells)` and `cells` alias.


def double_into(dest: Span[mut=True, Int, _], src: List[Int]):
    for index in range(len(dest)):
        dest[index] = src[index] * 2


def main():
    var cells: List[Int] = [3, 4]
    double_into(Span(cells), cells)
    print(cells)
```

[code/03-ownership/exclusivity_through_span_fails.mojo](code/03-ownership/exclusivity_through_span_fails.mojo)

This reaches further than you might expect. A value whose type carries a
*mutable* origin counts as mutable access to that origin, even when you pass
the value as an `imm` argument. Two recorders that each hold a mutable pointer
to the same log cannot travel into one call. The same rule applies when the
origin hides inside a pointee type, and when two pointers aim at
non-overlapping parts of one allocation: the checker compares origins, never
address ranges (chapters 5 and 9 meet both cases):

```mojo
# EXPECT-ERROR: two values that each embed a mutable reference to the same List
# EXPECT-MATCH: aliasing values passed mutably
# Claim (3.2): a value that carries a mutable origin counts as a mutable access
# to that origin. Two such values cannot go to one call, even as `imm` arguments.


struct Recorder[o: MutOrigin](Movable):
    var log: Pointer[List[String], Self.o]

    def __init__(out self, ref[Self.o] log: List[String]):
        self.log = Pointer(to=log)


def compare(first: Recorder, second: Recorder) -> Bool:
    return Int(first.log) == Int(second.log)


def main():
    var log = List[String]()
    var intake = Recorder(log)
    var outtake = Recorder(log)
    print(compare(intake, outtake))
```

[code/03-ownership/exclusivity_embedded_mut_refs_fails.mojo](code/03-ownership/exclusivity_embedded_mut_refs_fails.mojo)

### What the check does not cover

Trivial register-passable types (`Int`, `Bool`, `SIMD`) skip the check. The
callee receives copies, so no code can observe the aliasing:

```mojo
# Claim (3.2): trivial register-passable types (Int, Bool, SIMD) skip the
# exclusivity check because the callee receives copies. `step` keeps the value
# it had at the call, so the result is 3 + 3 + 3, not 3 + 3 + 6.
from std.testing import assert_equal


def bump_twice(mut count: Int, step: Int):
    count += step
    count += step


def main() raises:
    var count = 3
    bump_twice(count, count)
    assert_equal(count, 9)
```

[code/03-ownership/exclusivity_trivial_types_copy.mojo](code/03-ownership/exclusivity_trivial_types_copy.mojo)

Two distinct fields of one struct have distinct origins, so they never alias
each other:

```mojo
# Claim (3.2, 3.11): distinct fields of a struct have distinct origins, so one
# call may take both mutably.
from std.testing import assert_equal


@fieldwise_init
struct Bounds(Movable):
    var lower: String
    var upper: String


def main() raises:
    var bounds = Bounds("north", "south")
    swap(bounds.lower, bounds.upper)
    assert_equal(bounds.lower, "south")
    assert_equal(bounds.upper, "north")
```

[code/03-ownership/exclusivity_separate_fields.mojo](code/03-ownership/exclusivity_separate_fields.mojo)

A copy breaks the alias when you need the same contents twice. `append` with an
element of the same list compiles, because its `var` argument receives a copy
of the element before `append` gets mutable access to the list:

```mojo
# Claims (3.2):
# - Copying first gives the call two distinct values, so it compiles.
# - `List.append(names[0])` compiles: the `var` argument receives a copy of the
#   element before `append` gets mutable access to the list.
from std.testing import assert_equal


def append_twice(mut journal: String, entry: String):
    journal += entry
    journal += entry


def main() raises:
    var journal = String("boot;")
    var entry = journal.copy()
    append_twice(journal, entry)
    assert_equal(journal, "boot;boot;boot;")

    var names: List[String] = ["ada", "grace"]
    names.append(names[0])
    assert_equal(names, ["ada", "grace", "ada"])
```

[code/03-ownership/exclusivity_resolved_by_copy.mojo](code/03-ownership/exclusivity_resolved_by_copy.mojo)

Exclusivity is a property of a single call. A `Pointer` you created earlier
stays valid across a call that takes the same value `mut`; both writes land in
program order. That is sound for a single thread, and it is the reason the
check costs nothing at run time. It is also why the check says nothing about
threads (see chapter 8). Chapter 1 shows the stronger form: two mutable
`Pointer`s to one value, plus writes through the owner, all compile.

```mojo
# Claim (3.2): the compiler checks exclusivity between the arguments of one call. A
# Pointer created earlier stays valid across a call that takes the same value
# `mut`, and both writes land, in program order.
from std.testing import assert_equal


def bump(mut count: Int):
    count += 1


def main() raises:
    var count = 3
    var cursor = Pointer(to=count)
    bump(count)
    cursor[] += 10
    assert_equal(count, 14)
```

[code/03-ownership/exclusivity_is_per_call.mojo](code/03-ownership/exclusivity_is_per_call.mojo)

## 3.3 Lifetimes

*Rustonomicon counterpart: Lifetimes. Mojo calls them origins.*

An origin names *where* a reference points, not *how long* it lives. Lifetimes
fall out of it: the compiler knows which owner each reference depends on, keeps
the owner alive through the reference's last use, and rejects any use after the
owner moved or died.

Origins appear in three places:

- On `ref` results, as `-> ref[names[0]] String`.
- As parameters of types that hold references, as in `Pointer[T, origin]`,
  `Span[T, origin]`, or your own structs.
- Through `origin_of(path)`, which names the origin of a value path without
  evaluating it.

A `ref` result ties the returned reference to an argument, and the result's
mutability follows the argument's:

```mojo
# Claims (3.3):
# - `-> ref[names[0]] String` ties the result to the list's element origin.
# - Mutability follows the argument: a mutable list yields a writable reference,
#   an immutable one yields a read-only reference, from one function.
from std.testing import assert_equal


def first(ref names: List[String]) -> ref[names[0]] String:
    return names[0]


def first_length(names: List[String]) -> Int:
    return first(names).byte_length()


def main() raises:
    var crew: List[String] = ["ada", "grace"]
    first(crew) += "!"
    assert_equal(crew[0], "ada!")
    assert_equal(first_length(crew), 4)
```

[code/03-ownership/origin_from_argument.mojo](code/03-ownership/origin_from_argument.mojo)

```mojo
# EXPECT-ERROR: writing through a reference derived from an immutable argument
# EXPECT-MATCH: must be mutable
# Claim (3.3): the same `ref`-returning function gives back a read-only
# reference when its argument is immutable.


def first(ref names: List[String]) -> ref[names[0]] String:
    return names[0]


def shout(names: List[String]):
    first(names) += "!"


def main():
    var crew: List[String] = ["ada"]
    shout(crew)
```

[code/03-ownership/origin_parametric_mutability_fails.mojo](code/03-ownership/origin_parametric_mutability_fails.mojo)

### Structs that hold references

A type that stores a reference carries the referent's origin as a parameter.
The parameter is what lets the checker see through the struct:

```mojo
# Claims (3.3):
# - A struct that holds a reference carries the referent's origin as a parameter.
# - The view writes through to the owner, and its type names that owner.
# - `append` takes `self` immutably: the Cursor stays unchanged; the String it
#   points at changes.
from std.testing import assert_equal


struct Cursor[o: MutOrigin](ImplicitlyCopyable):
    var target: Pointer[String, Self.o]

    def __init__(out self, ref[Self.o] target: String):
        self.target = Pointer(to=target)

    def append(self, suffix: String):
        self.target[] += suffix


def main() raises:
    var manifest = String("crates:12")
    var cursor: Cursor[origin_of(manifest)] = Cursor(manifest)
    cursor.append(";drums:3")
    assert_equal(manifest, "crates:12;drums:3")
```

[code/03-ownership/view_struct_with_origin.mojo](code/03-ownership/view_struct_with_origin.mojo)

`append` takes `self` immutably and still writes. The Cursor does not change;
the `String` it points at does. Mutability of a view and mutability of the data
behind it are separate questions, and the origin answers the second one.

Because the type names the owner, moving the owner while the view still has
uses ahead of it fails:

```mojo
# EXPECT-ERROR: the owner moves away while a view of it is still used
# EXPECT-MATCH: use of uninitialized value 'manifest'
# Claim (3.3): a value whose type carries `origin_of(manifest)` counts as a use
# of `manifest` at each of its own uses.


struct Cursor[mut: Bool, //, o: Origin[mut=mut]](ImplicitlyCopyable):
    var target: Pointer[String, Self.o]

    def __init__(out self, ref[Self.o] target: String):
        self.target = Pointer(to=target)


def ship(var manifest: String):
    pass


def main():
    var manifest = String("crates:12")
    var cursor = Cursor(manifest)
    ship(manifest^)
    print(cursor.target[])
```

[code/03-ownership/view_blocks_transfer_fails.mojo](code/03-ownership/view_blocks_transfer_fails.mojo)

### Origins name paths

`origin_of()` takes a value path, so you can name one field of a struct. A
pointer typed with `origin_of(depot.north)` accepts only a pointer to that
field, and it leaves `depot.south` free:

```mojo
# Claims (3.3):
# - `origin_of()` accepts a value path such as `depot.north`, and names the
#   origin of that field only.
# - A pointer typed with a field origin accepts only a pointer to that field.
from std.testing import assert_equal


@fieldwise_init
struct Depot(Movable):
    var north: Int
    var south: Int


def main() raises:
    var depot = Depot(north=40, south=12)
    var bay: Pointer[Int, origin_of(depot.north)] = Pointer(to=depot.north)
    bay[] += 2
    depot.south += 1
    assert_equal(bay[], 42)
    assert_equal(depot.south, 13)
```

[code/03-ownership/origin_of_field_path.mojo](code/03-ownership/origin_of_field_path.mojo)

An origin must name storage that outlives the place you name it. A call result
is a temporary, so its origin cannot appear in a binding's type:

```mojo
# EXPECT-ERROR: an origin names a temporary that dies before the name is used
# EXPECT-MATCH: must outlive the expression naming it
# Claim (3.3): origins name storage that lives long enough. The result of a call
# is a temporary, so its origin cannot appear in a binding's type.


def load_route() -> String:
    return "A7"


def main():
    var route: Pointer[String, origin_of(load_route())]
```

[code/03-ownership/origin_must_outlive_fails.mojo](code/03-ownership/origin_must_outlive_fails.mojo)

## 3.4 Limits of origins

*Rustonomicon counterpart: Limits of Lifetimes.*

Origins approximate what a program does. Some approximations reject correct
code; others accept code that the checker cannot protect. Know both lists.

### Conservative: unions keep every member alive

A function that returns one of two references must declare the union of both
origins. The caller cannot know which one it got, so both owners live until
the reference's last use:

```mojo
# Claim (3.4): a reference with a union origin keeps every member alive, even
# the one the function did not pick. `backup` outlives the last use of `chosen`.
# Prints, in order: chose primary, deinit backup, deinit primary, end.


struct Probe(Movable):
    var label: String

    def __init__(out self, label: String):
        self.label = label

    def __deinit__(deinit self):
        print("deinit", self.label)


def pick[
    o1: Origin, o2: Origin, //
](use_first: Bool, ref[o1] first: Probe, ref[o2] second: Probe) -> ref[
    first, second
] Probe:
    if use_first:
        return first
    return second


def main():
    var primary = Probe("primary")
    var backup = Probe("backup")
    ref chosen = pick(True, primary, backup)
    print("chose", chosen.label)
    print("end")
```

[code/03-ownership/union_origin_extends_both.mojo](code/03-ownership/union_origin_extends_both.mojo)

Here `print("chose", chosen.label)` passes the field by reference into
`print`, so both probes survive through the whole call. Compare
section 3.1, where string concatenation produced a new value and ended the
borrow before the enclosing call ran.

### Conservative: invalidation is per call, not per reallocation

Element references carry the list's interior origin, and any `mut self` call on
the list invalidates them, whether or not it reallocates. `reserve(1)` on a
list that already holds two elements changes nothing at run time, and the
checker rejects the code anyway:

```mojo
# EXPECT-ERROR: an element reference held across a mut call on its List
# EXPECT-MATCH: use of invalidated interior reference
# Claim (3.4): any `mut self` call on a List invalidates element references,
# even `reserve(1)`, which never reallocates a list that already holds two.


def main():
    var names: List[String] = ["ada", "grace"]
    ref first = names[0]
    names.reserve(1)
    print(first)
```

[code/03-ownership/interior_invalidation_is_coarse_fails.mojo](code/03-ownership/interior_invalidation_is_coarse_fails.mojo)

Writing an element through subscript is not such a call, so references to
other elements survive it:

```mojo
# Claim (3.4): writing one element through subscript is not a `mut self` call
# that can reallocate, so a reference to another element stays valid.
from std.testing import assert_equal


def main() raises:
    var names: List[String] = ["ada", "grace"]
    ref first = names[0]
    names[1] = "linus"
    first += "!"
    assert_equal(names, ["ada!", "linus"])
```

[code/03-ownership/element_assignment_keeps_refs.mojo](code/03-ownership/element_assignment_keeps_refs.mojo)

### Accepted: conditional returns

A function may mutate its argument on one path and return a reference into it
on every path. The checker follows each path separately:

```mojo
# Claim (3.4): a function may mutate its argument on one path and return a
# reference into it on every path. The checker accepts this shape.
from std.testing import assert_equal


def slot(mut counts: List[Int], index: Int) -> ref[counts[0]] Int:
    if index >= len(counts):
        counts.append(0)
        return counts[len(counts) - 1]
    return counts[index]


def main() raises:
    var counts: List[Int] = [5]
    slot(counts, 0) += 1
    slot(counts, 7) += 1
    assert_equal(counts, [6, 1])
```

[code/03-ownership/conditional_return_ref.mojo](code/03-ownership/conditional_return_ref.mojo)

### Not caught: a Span across a List mutation

A `Span` built from a `List` carries the list's whole origin, not its interior
origin. `append` invalidates element references; it leaves a `Span` alone. The
following compiles, and the read is undefined behavior once `append`
reallocates the storage:

```mojo
# Undefined behavior: do not run.
var cells: List[Int] = [1, 2, 3, 4]
var view = Span(cells)
cells.append(5)   # may reallocate; `view` still points at the old storage
print(view[0])
```

The stdlib marks this as a known gap in `Span`'s `List` constructor. Until the
checker tracks it, treat every `mut` call on a list as the end of every `Span`
over it.

### Not caught: converting a tracked pointer to `MutAnyOrigin`

A function may return a `Pointer[T, MutAnyOrigin]` built from a pointer to a
local, and nothing in the code says `unsafe`. The local dies before the
function returns; the caller holds a dangling address. This sample proves the
ordering and never dereferences the result:

```mojo
# Claim (3.4): converting a tracked Pointer to `MutAnyOrigin` compiles in code
# with no `unsafe_` call, and the local it points at dies before the function
# returns. The caller receives a dangling address. This sample never
# dereferences it.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


def escape[o: MutOrigin](ref[o] log: List[String]) -> Pointer[Probe[o], MutAnyOrigin]:
    var local = Probe("local", log)
    var cursor = Pointer(to=local)
    log.append("returning")
    return cursor


def main() raises:
    var log = List[String]()
    var dangling = escape(log)
    log.append("caller holds address")
    _ = Int(dangling)
    assert_equal(log, ["deinit local", "returning", "caller holds address"])
```

[code/03-ownership/any_origin_conversion_drops_tracking.mojo](code/03-ownership/any_origin_conversion_drops_tracking.mojo)

`MutAnyOrigin` and `UnsafeAnyOrigin` name the same origin. Chapter 1 shows
the same escape from the safe/unsafe boundary side, and section 3.6 explains
why you should treat every spelling of this origin as unsafe.

## 3.5 Origin inference

*Rustonomicon counterpart: Lifetime Elision.*

Mojo does not elide result origins. A `ref` result always names its origin:

```mojo
# EXPECT-ERROR: a ref result without an origin specifier
# EXPECT-MATCH: requires an origin specifier
# Claim (3.5): Mojo never guesses a returned reference's origin; the signature
# must name it.


def first(ref names: List[String]) -> ref String:
    return names[0]


def main():
    var crew: List[String] = ["ada"]
    print(first(crew))
```

[code/03-ownership/ref_result_requires_origin_fails.mojo](code/03-ownership/ref_result_requires_origin_fails.mojo)

The name must match what the body returns. `ref[names]` (the whole list) and
`ref[names[0]]` (the list's elements) are different origins, and so are
`ref[self]` and `ref[self.scores]`:

```mojo
# EXPECT-ERROR: the declared origin is the whole list, but the body returns an element
# EXPECT-MATCH: incompatible origin
# Claim (3.5): `ref[names]` and `ref[names[0]]` are different origins. Element
# references carry the list's interior origin, and the signature must say so.


def first(ref names: List[String]) -> ref[names] String:
    return names[0]


def main():
    var crew: List[String] = ["ada"]
    print(first(crew))
```

[code/03-ownership/element_origin_mismatch_fails.mojo](code/03-ownership/element_origin_mismatch_fails.mojo)

```mojo
# EXPECT-ERROR: the declared origin is all of self, but the body returns one field
# EXPECT-MATCH: incompatible origin
# Claim (3.5): returning a field requires `ref[self.field]`, not `ref[self]`.


struct Roster(Movable):
    var team: String
    var scores: List[Int]

    def __init__(out self):
        self.team = "owls"
        self.scores = [70, 82]

    def scores_ref(mut self) -> ref[self] List[Int]:
        return self.scores


def main():
    var roster = Roster()
    print(len(roster.scores_ref()))
```

[code/03-ownership/field_origin_mismatch_fails.mojo](code/03-ownership/field_origin_mismatch_fails.mojo)

What Mojo does infer is the origin *parameter*. Parameters after `//` are
inferred from the arguments at each call. A bare `ref` argument infers an
anonymous origin, and you name it in the result by the argument's name, so the
two forms below mean the same thing:

```mojo
# Claims (3.5):
# - The compiler infers origins after `//` from the arguments at each call.
# - A bare `ref` argument infers an anonymous origin; `ref[left, right]` names it.
# - The result is mutable because both arguments are mutable.
from std.testing import assert_equal


def longest[
    o1: Origin, o2: Origin, //
](ref[o1] left: String, ref[o2] right: String) -> ref[left, right] String:
    if left.byte_length() >= right.byte_length():
        return left
    return right


def shorter(ref left: String, ref right: String) -> ref[left, right] String:
    if left.byte_length() < right.byte_length():
        return left
    return right


def main() raises:
    var harbor = String("harbor")
    var bay = String("bay")
    longest(harbor, bay) += "!"
    shorter(harbor, bay) += "?"
    assert_equal(harbor, "harbor!")
    assert_equal(bay, "bay?")
```

[code/03-ownership/inferred_origin_parameters.mojo](code/03-ownership/inferred_origin_parameters.mojo)

`Pointer(to=value)` infers both the pointee type and the origin, and a `_` in a
parameter list accepts any origin and binds it at the call:

```mojo
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
```

[code/03-ownership/pointer_to_infers_origin.mojo](code/03-ownership/pointer_to_infers_origin.mojo)

## 3.6 Unbounded origins

*Rustonomicon counterpart: Unbounded Lifetimes.*

Two origins sit outside normal tracking, and they fail in opposite directions.

| Origin | What the checker assumes | Effect on other values |
| --- | --- | --- |
| `MutUntrackedOrigin`, `ImmUntrackedOrigin` | The reference aliases no value Mojo manages. | Keeps nothing alive. Owners die on schedule even while the pointer lives. |
| `UnsafeAnyOrigin` (also spelled `MutAnyOrigin`, `ImmutAnyOrigin`) | The reference might alias any live value. | Keeps every value in scope alive, disables exclusivity checks for it, and hides unused-value warnings. |

`alloc()` storage carries an untracked origin, because no Mojo value owns it.
That is the right origin for memory you manage by hand. It is the wrong origin
for a pointer into a Mojo value, because the owner's destruction no longer
waits for the pointer:

```mojo
# Claims (3.6, 3.9):
# - A pointer cast to `MutUntrackedOrigin` no longer counts as a use of its
#   owner, so the owner dies at its last tracked use.
# - Converting a pointer to `Int` and passing a pointer to a function both
#   count as uses; the owner dies right after that use, before the enclosing
#   statement finishes.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


def still_held(cursor: Pointer) -> Bool:
    return True


def main() raises:
    var log = List[String]()
    var by_address = Probe("by_address", log)
    var by_call = Probe("by_call", log)
    var untracked = Probe("untracked", log)
    var address_cursor = Pointer(to=by_address)
    var call_cursor = Pointer(to=by_call)
    var raw_cursor = Pointer(to=untracked).unsafe_origin_cast[
        MutUntrackedOrigin
    ]()
    log.append("pointers made")
    _ = Int(address_cursor)
    log.append("after address")
    _ = still_held(call_cursor)
    log.append("after call")
    _ = still_held(raw_cursor)
    log.append("end")
    assert_equal(
        log,
        [
            "deinit untracked",
            "pointers made",
            "deinit by_address",
            "after address",
            "deinit by_call",
            "after call",
            "end",
        ],
    )
```

[code/03-ownership/untracked_does_not_extend.mojo](code/03-ownership/untracked_does_not_extend.mojo)

`untracked` dies before the log records anything: its last tracked use was
`Pointer(to=untracked)` itself. The two tracked owners die right after the
expression that last uses their pointer, even when that use only reads the
address with `Int()`.

The wildcard origin fails the other way. It pins everything, including values
created after it and values it never pointed at:

```mojo
# Claim (3.6): while a pointer with `UnsafeAnyOrigin` lives, every value in
# scope stays alive, including values it never pointed at and values created
# after it. ASAP destruction resumes after its last use.
# Prints, in order: pointer made, filler made, reading anchor,
# then the three deinit lines (filler, unrelated, anchor), then end.


struct Probe(Movable):
    var label: String

    def __init__(out self, label: String):
        self.label = label

    def __deinit__(deinit self):
        print("deinit", self.label)


def main():
    var anchor = Probe("anchor")
    var unrelated = Probe("unrelated")
    var wildcard = Pointer(to=anchor).as_unsafe_any_origin()
    print("pointer made")
    var filler = Probe("filler")
    print("filler made")
    print("reading", wildcard[].label)
    print("end")
```

[code/03-ownership/unsafe_any_origin_extends_everything.mojo](code/03-ownership/unsafe_any_origin_extends_everything.mojo)

The stdlib marks `UnsafeAnyOrigin` as a temporary escape hatch slated for
removal. Prefer a concrete origin every time.

### Rebinding raw storage to an owner

`alloc()` returns an `Allocation`, a linear handle. Its `unsafe_ptr()` carries
the allocation's own origin, so the checker catches a use after `dealloc`:

```mojo
# EXPECT-ERROR: dereferencing an Allocation's pointer after dealloc consumed it
# EXPECT-MATCH: use of uninitialized value 'block'
# Claim (3.6): `Allocation.unsafe_ptr()` returns a pointer whose origin is the
# Allocation, so a use-after-free through it fails to compile.
from std.memory import alloc, dealloc, Layout


def main():
    var block = alloc(Layout[Int](length=2))
    var cursor = block.unsafe_ptr()
    cursor.write(7)
    dealloc(block^)
    print(cursor[])
```

[code/03-ownership/allocation_pointer_tracked_fails.mojo](code/03-ownership/allocation_pointer_tracked_fails.mojo)

A struct that keeps raw storage in an untracked field can restore tracking at
its public surface. `unsafe_mut_cast` adjusts mutability to match `self`, and
`unsafe_origin_cast` binds the pointer to `origin_of(self)`. From then on the
ordinary rules protect every view:

```mojo
# Claims (3.6):
# - A struct can own untracked storage and hand out pointers bound to its own
#   origin with `unsafe_mut_cast` plus `unsafe_origin_cast`.
# - Those views keep the owner alive, so its `__deinit__` (which frees the
#   storage) runs only after the last view use.
from std.memory import alloc, dealloc, Layout, ThinAllocation
from std.testing import assert_equal


struct Samples[o: MutOrigin](Movable):
    var raw: Pointer[Float64, MutUntrackedOrigin]
    var count: Int
    var log: Pointer[List[String], Self.o]

    def __init__(out self, count: Int, ref[Self.o] log: List[String]):
        self.raw = alloc(Layout[Float64](length=count)).unsafe_leak()
        self.count = count
        self.log = Pointer(to=log)
        for index in range(count):
            self.raw.unsafe_offset(index).write(Float64(index) * 0.5)

    def view(ref self) -> Pointer[Float64, origin_of(self)]:
        return self.raw.unsafe_mut_cast[
            origin_of(self).mut
        ]().unsafe_origin_cast[origin_of(self)]()

    def __deinit__(deinit self):
        self.log[].append("freed")
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.raw).unsafe_with_layout(
                Layout[Float64](length=self.count)
            )
        )


def main() raises:
    var log = List[String]()
    var samples = Samples(4, log)
    var readings = samples.view()
    readings[unsafe_offset=1] = 9.25
    log.append("wrote")
    var third = readings[unsafe_offset=3]
    log.append("read")
    assert_equal(third, 1.5)
    assert_equal(log, ["wrote", "freed", "read"])
```

[code/03-ownership/bind_untracked_to_owner.mojo](code/03-ownership/bind_untracked_to_owner.mojo)

```mojo
# EXPECT-ERROR: the storage owner moves away while a bound view is still used
# EXPECT-MATCH: use of uninitialized value 'samples'
# Claim (3.6): once a raw pointer carries `origin_of(self)`, the ordinary
# ownership rules protect it.
from std.memory import alloc, dealloc, Layout, ThinAllocation


struct Samples(Movable):
    var raw: Pointer[Float64, MutUntrackedOrigin]
    var count: Int

    def __init__(out self, count: Int):
        self.raw = alloc(Layout[Float64](length=count)).unsafe_leak()
        self.count = count
        for index in range(count):
            self.raw.unsafe_offset(index).write(Float64(index))

    def view(ref self) -> Pointer[Float64, origin_of(self)]:
        return self.raw.unsafe_mut_cast[
            origin_of(self).mut
        ]().unsafe_origin_cast[origin_of(self)]()

    def __deinit__(deinit self):
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.raw).unsafe_with_layout(
                Layout[Float64](length=self.count)
            )
        )


def archive(var samples: Samples):
    pass


def main():
    var samples = Samples(4)
    var readings = samples.view()
    archive(samples^)
    print(readings[])
```

[code/03-ownership/bound_view_blocks_transfer_fails.mojo](code/03-ownership/bound_view_blocks_transfer_fails.mojo)

### The field-copy trap

The reverse direction carries the sharpest hazard in this chapter. Copying an
untracked pointer field out of its owner is a use of the owner. If nothing uses
the owner afterward, that copy is the owner's last use. The owner's
`__deinit__` runs and frees the storage, and the copied pointer dangles before
the next statement:

```mojo
# Claim (3.6): copying an untracked pointer field out of its owner is the
# owner's last use when nothing else follows. The owner's `__deinit__` frees
# the storage before the next statement runs. This sample stops at the copy;
# reading through `raw` afterward would be undefined behavior.
from std.memory import alloc, dealloc, Layout, ThinAllocation
from std.testing import assert_equal


struct Samples[o: MutOrigin](Movable):
    var raw: Pointer[Float64, MutUntrackedOrigin]
    var log: Pointer[List[String], Self.o]

    def __init__(out self, ref[Self.o] log: List[String]):
        self.raw = alloc(Layout[Float64](length=2)).unsafe_leak()
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("freed")
        dealloc(
            ThinAllocation(unsafe_owned_ptr=self.raw).unsafe_with_layout(
                Layout[Float64](length=2)
            )
        )


def main() raises:
    var log = List[String]()
    var samples = Samples(log)
    var raw = samples.raw
    log.append("copied pointer")
    _ = Int(raw)
    assert_equal(log, ["freed", "copied pointer"])
```

[code/03-ownership/untracked_field_copy_ends_owner.mojo](code/03-ownership/untracked_field_copy_ends_owner.mojo)

The sample stops at the copy. Reading through `raw` afterward is undefined
behavior. Never hand out an untracked field; return a view bound to
`origin_of(self)` instead.

## 3.7 Higher-rank bounds

*Rustonomicon counterpart: Higher-Rank Trait Bounds. Mojo has no syntax for
them; function types already range over all origins.*

A function type such as `def(mut Int) -> None` does not mention an origin for
its argument. Any function value of that type accepts a reference with any
origin at each call, which is exactly the property a higher-rank bound
expresses:

```mojo
# Claims (3.7):
# - A function-typed argument with a `mut` parameter accepts references with
#   any origin; the callee chooses which values it lends.
# - A closure lists its captures in `{}`; `mut calls` captures by mutable reference.
from std.testing import assert_equal


def apply_each(mut readings: List[Int], adjust: Some[def(mut Int) -> None]):
    for ref reading in readings:
        adjust(reading)


def main() raises:
    var readings: List[Int] = [3, 7]
    var calls = 0

    def offset(mut reading: Int) {mut calls}:
        reading += 100
        calls += 1

    apply_each(readings, offset)
    assert_equal(readings, [103, 107])
    assert_equal(calls, 2)
```

[code/03-ownership/callback_any_origin.mojo](code/03-ownership/callback_any_origin.mojo)

The callee can lend a value that exists only inside itself. The caller never
names its origin, and the reference cannot escape the call:

```mojo
# Claim (3.7): a callback can receive a reference to a value that lives only
# inside the callee. The caller never names that value's origin, and the
# reference cannot outlive the call.
from std.testing import assert_equal


def with_scratch(work: Some[def(mut List[Int]) -> Int]) -> Int:
    var scratch = List[Int](capacity=8)
    return work(scratch)


def main() raises:
    def fill_and_sum(mut scratch: List[Int]) -> Int:
        for reading in [12, 30, 8]:
            scratch.append(reading)
        var total = 0
        for reading in scratch:
            total += reading
        return total

    assert_equal(with_scratch(fill_and_sum), 50)
```

[code/03-ownership/callback_borrows_callee_local.mojo](code/03-ownership/callback_borrows_callee_local.mojo)

### Captures

A nested `def` lists what it captures in `{}`, with a convention per name:

```mojo
# Claims (3.7):
# - A capture with no convention reads the captured value at call time
#   (it captures a reference, not a snapshot).
# - `var` captures a copy when the closure forms.
# - `mut` captures a mutable reference.
from std.testing import assert_equal


def main() raises:
    var status = String("idle")

    def current() {status} -> String:
        return status

    def snapshot() {var status} -> String:
        return status

    def advance(next: String) {mut status}:
        status = next

    advance("running")
    assert_equal(current(), "running")
    assert_equal(snapshot(), "idle")
    assert_equal(status, "running")
```

[code/03-ownership/closure_capture_modes.mojo](code/03-ownership/closure_capture_modes.mojo)

A capture without a convention captures a reference and reads the value at
call time. `var` copies when the closure forms. `mut` captures a mutable
reference. Calling a closure counts as a use of everything it captured by
reference, so the owner cannot move away while calls remain:

```mojo
# EXPECT-ERROR: a closure that captured `journal` runs after `journal` moved away
# EXPECT-MATCH: use of uninitialized value 'journal'
# Claim (3.7): calling a closure counts as a use of everything it captured by
# reference.


def main():
    var journal = String("start")

    def record(entry: String) {mut journal}:
        journal += entry

    record(";one")
    var archived = journal^
    record(";two")
    print(archived)
```

[code/03-ownership/closure_capture_is_use_fails.mojo](code/03-ownership/closure_capture_is_use_fails.mojo)

## 3.8 Subtyping and variance

*Rustonomicon counterpart: Subtyping and Variance. Mojo has no subtyping
between types; implicit conversions fill the role.*

Mojo structs do not form subtype relationships, and origin parameters are
invariant. A `Cursor[mutable origin]` is not a `Cursor[immutable origin]`. The
one relationship that matters in practice, "a mutable borrow can stand in for
an immutable one", comes from `@implicit` constructors. `Pointer` and `Span`
declare them:

```mojo
# Claims (3.8):
# - A mutable `Pointer` or `Span` converts implicitly to its immutable form
#   wherever a function asks for an immutable origin.
from std.testing import assert_equal


def byte_count[o: ImmOrigin](cursor: Pointer[String, o]) -> Int:
    return cursor[].byte_length()


def total[o: ImmOrigin](readings: Span[Int, o]) -> Int:
    var sum = 0
    for reading in readings:
        sum += reading
    return sum


def main() raises:
    var city = String("Quito")
    assert_equal(byte_count(Pointer(to=city)), 5)
    var counts: List[Int] = [4, 5]
    assert_equal(total(Span(counts)), 9)
```

[code/03-ownership/mut_pointer_converts_to_imm.mojo](code/03-ownership/mut_pointer_converts_to_imm.mojo)

The conversion runs one way:

```mojo
# EXPECT-ERROR: an immutable pointer cannot convert back to a mutable one
# EXPECT-MATCH: cannot implicitly convert
# Claim (3.8): the conversion runs one way, mutable to immutable.


def main():
    var city = String("Kyiv")
    var reader = Pointer(to=city).as_imm()
    var writer: Pointer[String, origin_of(city)] = reader
    print(writer[])
```

[code/03-ownership/imm_pointer_to_mut_fails.mojo](code/03-ownership/imm_pointer_to_mut_fails.mojo)

Your own view types get no conversion until you declare one:

```mojo
# EXPECT-ERROR: a user view type does not convert from mutable to immutable origin
# EXPECT-MATCH: cannot be converted from 'Cursor
# Claim (3.8): origin parameters are invariant. A struct gets the
# mutable-to-immutable conversion only if it declares one.


struct Cursor[mut: Bool, //, o: Origin[mut=mut]](ImplicitlyCopyable):
    var target: Pointer[String, Self.o]

    def __init__(out self, ref[Self.o] target: String):
        self.target = Pointer(to=target)


def peek[o: ImmOrigin](cursor: Cursor[o]) -> Int:
    return cursor.target[].byte_length()


def main():
    var city = String("Quito")
    var cursor = Cursor(city)
    print(peek(cursor))
```

[code/03-ownership/user_view_without_conversion_fails.mojo](code/03-ownership/user_view_without_conversion_fails.mojo)

The declaration mirrors the one in `Pointer`: an `@implicit` constructor that
takes any `Cursor` and produces a `Cursor` over `ImmOrigin(other.o)`:

```mojo
# Claims (3.8):
# - An `@implicit` constructor from `Cursor` to `Cursor[ImmOrigin(other.o)]`
#   gives a user view the mutable-to-immutable conversion.
# - The original mutable view stays usable for writes.
from std.testing import assert_equal


struct Cursor[mut: Bool, //, o: Origin[mut=mut]](ImplicitlyCopyable):
    var target: Pointer[String, Self.o]

    def __init__(out self, ref[Self.o] target: String):
        self.target = Pointer(to=target)

    @implicit
    def __init__(other: Cursor, out self: Cursor[ImmOrigin(other.o)]):
        self.target = other.target


def peek[o: ImmOrigin](cursor: Cursor[o]) -> Int:
    return cursor.target[].byte_length()


def main() raises:
    var city = String("Quito")
    var cursor = Cursor(city)
    assert_equal(peek(cursor), 5)
    cursor.target[] += "!"
    assert_equal(city, "Quito!")
```

[code/03-ownership/user_view_opt_in_conversion.mojo](code/03-ownership/user_view_opt_in_conversion.mojo)

### Merging origins

When two pointers with different origins meet, as in the arms of a conditional
expression, Mojo merges them into a pointer whose origin is the union. The
result is mutable only if both inputs are:

```mojo
# Claims (3.8):
# - Two pointers with different origins merge into one pointer whose origin is
#   the union of both.
# - The merged pointer stays mutable when both inputs are mutable.
from std.testing import assert_equal


def main() raises:
    var north = String("north")
    var south = String("south")
    var heading_north = True
    var heading = Pointer(to=north) if heading_north else Pointer(to=south)
    heading[] += "!"
    assert_equal(north, "north!")
    assert_equal(south, "south")
```

[code/03-ownership/ternary_merges_origins.mojo](code/03-ownership/ternary_merges_origins.mojo)

```mojo
# EXPECT-ERROR: merging a mutable and an immutable pointer yields an immutable one
# EXPECT-MATCH: must be mutable
# Claim (3.8): a union origin is mutable only when every member is mutable.


def main():
    var north = String("north")
    var south = String("south")
    var heading_north = True
    var heading = (
        Pointer(to=north) if heading_north else Pointer(to=south).as_imm()
    )
    heading[] += "!"
```

[code/03-ownership/ternary_mixed_mutability_fails.mojo](code/03-ownership/ternary_mixed_mutability_fails.mojo)

## 3.9 Drop check

*Rustonomicon counterpart: Drop Check.*

Destruction order in Mojo follows uses, not scopes. The rules:

1. A value dies right after its last use, which can fall in the middle of a
   statement.
2. A reference counts as a use of its owner, so an owner outlives every
   reference to it, including references stored in other values.
3. A value with no uses at all dies right after it forms.
4. Inside `__deinit__`, each field dies after its last use in the body; fields
   the body never reads die before the body starts.
5. `deinit(value^)` moves the last use to that line.

Rule 2 is the whole of drop checking. A holder whose `__deinit__` reads through
a stored pointer runs before its referent dies, with no annotation:

```mojo
# Claims (3.9):
# - A struct whose `__deinit__` reads through a stored pointer runs that
#   deinitializer before its referent dies; the referent outlives the holder.
# - An unused holder dies right after construction.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


struct Inspector[log_origin: MutOrigin, o: ImmOrigin](Movable):
    var target: Pointer[Probe[Self.log_origin], Self.o]

    def __init__(out self, ref[Self.o] target: Probe[Self.log_origin]):
        self.target = Pointer(to=target)

    def __deinit__(deinit self):
        self.target[].log[].append("inspected " + self.target[].label)


def main() raises:
    var log = List[String]()
    var gauge = Probe("gauge", log)
    _ = Inspector(gauge)
    log.append("end")
    assert_equal(log, ["inspected gauge", "deinit gauge", "end"])
```

[code/03-ownership/holder_deinit_reads_referent.mojo](code/03-ownership/holder_deinit_reads_referent.mojo)

Rule 4 surprises anyone who expects the body to run first and the fields to
die after:

```mojo
# Claims (3.9):
# - Inside `__deinit__`, fields the body never reads die before the body runs,
#   in declaration order.
# - A field the body reads dies right after that read.
# Prints, in order: deinit first, deinit third, body start, reading second,
# deinit second, body end, end.


struct Probe(Movable):
    var label: String

    def __init__(out self, label: String):
        self.label = label

    def __deinit__(deinit self):
        print("deinit", self.label)


struct Trio(Movable):
    var first: Probe
    var second: Probe
    var third: Probe

    def __init__(out self):
        self.first = Probe("first")
        self.second = Probe("second")
        self.third = Probe("third")

    def __deinit__(deinit self):
        print("body start")
        print("reading", self.second.label)
        print("body end")


def main():
    _ = Trio()
    print("end")
```

[code/03-ownership/deinit_fields_die_at_last_use.mojo](code/03-ownership/deinit_fields_die_at_last_use.mojo)

`first` and `third` die before `"body start"`. `second` lives through the line
that reads it. If your teardown logic depends on a field staying alive, read
that field in the body at the point you need it.

Rule 1 applies to reassignment too. The old value does not wait for the `=`:

```mojo
# Claims (3.9):
# - Reassignment does not keep the old value alive until the `=`. The old
#   value dies after its own last use, here right after construction.
# - The new value dies right after the expression that last reads it, before
#   the enclosing call (`log.append`) runs.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


def main() raises:
    var log = List[String]()
    var shift = Probe("morning", log)
    log.append("reassigning")
    shift = Probe("evening", log)
    log.append("reassigned " + shift.label)
    assert_equal(
        log,
        ["deinit morning", "reassigning", "deinit evening", "reassigned evening"],
    )
```

[code/03-ownership/reassignment_old_value_dies_early.mojo](code/03-ownership/reassignment_old_value_dies_early.mojo)

### Guards

ASAP destruction turns a scope guard inside out. A guard you never use dies
right after construction:

```mojo
# Claim (3.9): without a later use, a guard dies right after construction.
# This is the ASAP rule that makes `deinit(guard^)` necessary.
from std.testing import assert_equal


struct Guard[o: MutOrigin](Movable):
    var counter: Pointer[Int, Self.o]

    def __init__(out self, ref[Self.o] counter: Int):
        self.counter = Pointer(to=counter)

    def __deinit__(deinit self):
        self.counter[] += 1


def main() raises:
    var released = 0
    _ = Guard(released)
    assert_equal(released, 1)
```

[code/03-ownership/guard_without_deinit_call.mojo](code/03-ownership/guard_without_deinit_call.mojo)

`deinit(guard^)` pins the effect to a line of your choosing:

```mojo
# Claim (3.9): `deinit(value^)` moves the last use to that line, so a guard
# whose effect lives in its deinitializer acts there and not at construction.
from std.testing import assert_equal


struct Guard[o: MutOrigin](Movable):
    var counter: Pointer[Int, Self.o]

    def __init__(out self, ref[Self.o] counter: Int):
        self.counter = Pointer(to=counter)

    def __deinit__(deinit self):
        self.counter[] += 1


def main() raises:
    var released = 0
    var guard = Guard(released)
    assert_equal(released, 0)
    deinit(guard^)
    assert_equal(released, 1)
```

[code/03-ownership/explicit_deinit_extends.mojo](code/03-ownership/explicit_deinit_extends.mojo)

### Linear types

A type declared `not Deinitable` has no implicit destruction at all. The
compiler requires every value to end in a `deinit` method or a transfer, on
every path:

```mojo
# EXPECT-ERROR: a value of a non-Deinitable type reaches the end of its life unconsumed
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim (3.9): a `not Deinitable` type has no implicit destruction; every path
# must end in a `deinit` method or a transfer.


struct Receipt(not Deinitable, Movable):
    var amount: Int

    def __init__(out self, amount: Int):
        self.amount = amount

    def file(deinit self) -> Int:
        return self.amount


def main():
    var receipt = Receipt(120)
    print(receipt.amount)
```

[code/03-ownership/linear_value_abandoned_fails.mojo](code/03-ownership/linear_value_abandoned_fails.mojo)

```mojo
# Claim (3.9): consuming a linear value through its `deinit` method satisfies
# the checker.
from std.testing import assert_equal


struct Receipt(not Deinitable, Movable):
    var amount: Int

    def __init__(out self, amount: Int):
        self.amount = amount

    def file(deinit self) -> Int:
        return self.amount


def main() raises:
    var receipt = Receipt(120)
    assert_equal(receipt^.file(), 120)
```

[code/03-ownership/linear_value_consumed.mojo](code/03-ownership/linear_value_consumed.mojo)

Chapter 6 builds on linear types; `Allocation` is one.

## 3.10 PhantomData

*Rustonomicon counterpart: PhantomData. Mojo needs no marker type; parameters
and conditional conformances carry the same information.*

### Phantom origins

A struct that declares an origin parameter borrows that origin, whether or not
it stores a pointer. A handle that holds only an index can still pin its arena:

```mojo
# Claim (3.10): a struct that only carries an origin parameter, with no pointer
# field, still keeps that origin's owner alive while the struct lives.
from std.testing import assert_equal


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


struct Ticket[o: ImmOrigin](ImplicitlyCopyable):
    var slot: Int

    def __init__[
        log_origin: MutOrigin
    ](out self, ref[Self.o] arena: Probe[log_origin], slot: Int):
        self.slot = slot


def redeem(ticket: Ticket) -> Int:
    return ticket.slot


def main() raises:
    var log = List[String]()
    var arena = Probe("arena", log)
    var ticket = Ticket(arena, 3)
    log.append("ticket issued")
    var slot = redeem(ticket)
    log.append("redeemed")
    assert_equal(slot, 3)
    assert_equal(log, ["ticket issued", "deinit arena", "redeemed"])
```

[code/03-ownership/phantom_origin_keeps_owner_alive.mojo](code/03-ownership/phantom_origin_keeps_owner_alive.mojo)

```mojo
# EXPECT-ERROR: the arena moves away while a ticket bound to its origin is still used
# EXPECT-MATCH: use of uninitialized value 'arena'
# Claim (3.10): an origin parameter alone is enough for the checker to treat
# the ticket as a borrow of the arena.


struct Ticket[o: ImmOrigin](ImplicitlyCopyable):
    var slot: Int

    def __init__(out self, ref[Self.o] arena: List[Int], slot: Int):
        self.slot = slot


def redeem(ticket: Ticket) -> Int:
    return ticket.slot


def main():
    var arena: List[Int] = [10, 20]
    var ticket = Ticket(arena, 1)
    var moved = arena^
    print(redeem(ticket), len(moved))
```

[code/03-ownership/phantom_origin_blocks_transfer_fails.mojo](code/03-ownership/phantom_origin_blocks_transfer_fails.mojo)

### Phantom types

An unused type parameter still distinguishes types, at no storage cost:

```mojo
# EXPECT-ERROR: an Id tagged for invoices passed where the function requires a customer Id
# EXPECT-MATCH: cannot be converted from 'Id\[Invoice\]' to 'Id\[Customer\]'
# Claim (3.10): an unused type parameter still distinguishes types.


struct Customer:
    pass


struct Invoice:
    pass


@fieldwise_init
struct Id[Kind: AnyType](ImplicitlyCopyable):
    var value: Int


def load_customer(id: Id[Customer]) -> String:
    return "customer-" + String(id.value)


def main():
    var invoice_id = Id[Invoice](4021)
    print(load_customer(invoice_id))
```

[code/03-ownership/phantom_type_tag_fails.mojo](code/03-ownership/phantom_type_tag_fails.mojo)

```mojo
# Claim (3.10): a phantom type parameter adds no storage; `Id[Customer]` has
# the size of its one `Int` field.
from std.sys import size_of
from std.testing import assert_equal


struct Customer:
    pass


@fieldwise_init
struct Id[Kind: AnyType](ImplicitlyCopyable):
    var value: Int


def main() raises:
    assert_equal(size_of[Id[Customer]](), size_of[Int]())
```

[code/03-ownership/phantom_type_tag_layout.mojo](code/03-ownership/phantom_type_tag_layout.mojo)

### Owning a `T` through raw storage

A container that holds its elements through an `Allocation` must tell the
compiler that it owns them, so that destroying the container destroys the
elements and a linear element makes the container linear. The conditional
conformance `Deinitable where conforms_to(T, Deinitable)` says both. `List`
declares exactly this:

```mojo
# Claims (3.10):
# - A container that owns a `T` through raw storage states that ownership with
#   `Deinitable where conforms_to(T, Deinitable)`.
# - With a Deinitable `T`, the container destroys its element automatically.
# - With a linear `T`, the container becomes linear too and needs a consuming
#   method such as `into_inner`.
from std.memory import alloc, dealloc, Layout, Allocation
from std.testing import assert_equal


struct Cell[T: Movable](Deinitable where conforms_to(T, Deinitable), Movable):
    var storage: Allocation[Self.T]

    def __init__(out self, var value: Self.T):
        self.storage = alloc(Layout[Self.T].single())
        self.storage.unsafe_ptr().unsafe_write(value^)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        self.storage.unsafe_ptr().unsafe_deinit_pointee()
        dealloc(self.storage^)

    def into_inner(deinit self) -> Self.T:
        var value = self.storage.unsafe_ptr().unsafe_take_pointee()
        dealloc(self.storage^)
        return value^


struct Probe[o: MutOrigin](Movable):
    var label: String
    var log: Pointer[List[String], Self.o]

    def __init__(out self, label: String, ref[Self.o] log: List[String]):
        self.label = label
        self.log = Pointer(to=log)

    def __deinit__(deinit self):
        self.log[].append("deinit " + self.label)


struct Receipt(not Deinitable, Movable):
    var amount: Int

    def __init__(out self, amount: Int):
        self.amount = amount

    def file(deinit self) -> Int:
        return self.amount


def main() raises:
    var log = List[String]()
    _ = Cell(Probe("boxed", log))
    log.append("cell gone")
    assert_equal(log, ["deinit boxed", "cell gone"])

    var receipt_cell = Cell(Receipt(120))
    assert_equal(receipt_cell^.into_inner().file(), 120)
```

[code/03-ownership/conditional_deinitable_owner.mojo](code/03-ownership/conditional_deinitable_owner.mojo)

```mojo
# EXPECT-ERROR: the program abandons a Cell that holds a linear Receipt
# EXPECT-MATCH: does not conditionally conform to 'Deinitable'
# Claim (3.10): the conditional conformance carries the element's linearity to
# the container.
from std.memory import alloc, dealloc, Layout, Allocation


struct Cell[T: Movable](Deinitable where conforms_to(T, Deinitable), Movable):
    var storage: Allocation[Self.T]

    def __init__(out self, var value: Self.T):
        self.storage = alloc(Layout[Self.T].single())
        self.storage.unsafe_ptr().unsafe_write(value^)

    def __deinit__(deinit self) where conforms_to(Self.T, Deinitable):
        self.storage.unsafe_ptr().unsafe_deinit_pointee()
        dealloc(self.storage^)


struct Receipt(not Deinitable, Movable):
    var amount: Int

    def __init__(out self, amount: Int):
        self.amount = amount

    def file(deinit self) -> Int:
        return self.amount


def main():
    var receipt_cell = Cell(Receipt(120))
    print("never filed")
```

[code/03-ownership/conditional_deinitable_linear_fails.mojo](code/03-ownership/conditional_deinitable_linear_fails.mojo)

Leave out the conditional conformance and write an unconditional
`__deinit__` that only deallocates, and a `Cell[Receipt]` compiles, and drops
its receipt without running any consuming method. The conformance is what keeps
linearity from leaking through a container.

## 3.11 Splitting borrows

*Rustonomicon counterpart: Splitting Borrows.*

The checker splits borrows along fields. It does not split them along indices.

### Fields split

Two fields of one struct have distinct origins, so one call may take both
mutably:

```mojo
# Claim (3.11): one call can take two fields of the same struct mutably,
# because each field has its own origin.
from std.testing import assert_equal


struct Fixture(Movable):
    var home: List[Int]
    var away: List[Int]

    def __init__(out self):
        self.home = [3, 1, 4]
        self.away = [2]


def rebalance(mut longer: List[Int], mut shorter: List[Int]):
    while len(longer) > len(shorter) + 1:
        shorter.append(longer.pop())


def main() raises:
    var fixture = Fixture()
    rebalance(fixture.home, fixture.away)
    assert_equal(fixture.home, [3, 1])
    assert_equal(fixture.away, [2, 4])
```

[code/03-ownership/split_fields_into_one_call.mojo](code/03-ownership/split_fields_into_one_call.mojo)

A method that returns `ref[self.scores]` borrows only that field. Other
fields stay writable while the reference lives, and so does a `mut self`
method:

```mojo
# Claims (3.11):
# - A method returning `ref[self.scores]` borrows only that field.
# - While the reference lives, other fields stay writable, and even a
#   `mut self` method that touches only `team` compiles.
from std.testing import assert_equal


struct Roster(Movable):
    var team: String
    var scores: List[Int]

    def __init__(out self):
        self.team = "owls"
        self.scores = [70, 82]

    def scores_ref(mut self) -> ref[self.scores] List[Int]:
        return self.scores

    def rename(mut self, team: String):
        self.team = team


def main() raises:
    var roster = Roster()
    ref scores = roster.scores_ref()
    roster.team = "hawks"
    roster.rename("ravens")
    scores.append(91)
    assert_equal(roster.team, "ravens")
    assert_equal(roster.scores, [70, 82, 91])
```

[code/03-ownership/field_origin_return.mojo](code/03-ownership/field_origin_return.mojo)

### Elements do not split

Every element of a `List` shares one interior origin. Local `ref` bindings to
two elements can both write, because exclusivity governs call arguments, not
bindings:

```mojo
# Claim (3.11): two `ref` bindings to different elements of one List can both
# write. Exclusivity applies to the arguments of a call, not to local bindings.
from std.testing import assert_equal


def main() raises:
    var cells: List[Int] = [1, 2, 3, 4]
    ref first = cells[0]
    ref last = cells[3]
    first += 10
    last += 20
    assert_equal(cells, [11, 2, 3, 24])
```

[code/03-ownership/element_ref_bindings.mojo](code/03-ownership/element_ref_bindings.mojo)

A call that takes two elements fails (section 3.2). The API answer is a method
that takes the container once and two indices:

```mojo
# Claim (3.11): `List.swap_elements` takes the list once and two indices, so it
# sidesteps the aliasing check that rejects `swap(temps[0], temps[2])`.
# `Span.swap_elements` does the same on a view, and raises on a bad index.
from std.testing import assert_equal


def main() raises:
    var temps: List[Int] = [12, 18, 25]
    temps.swap_elements(0, 2)
    assert_equal(temps, [25, 18, 12])

    var view = Span(temps)
    view.swap_elements(0, 1)
    assert_equal(temps, [18, 25, 12])
```

[code/03-ownership/swap_elements_by_index.mojo](code/03-ownership/swap_elements_by_index.mojo)

Subspans keep their parent's origin, so two non-overlapping halves still alias
as far as the checker can tell:

```mojo
# EXPECT-ERROR: two halves of one Span passed to one call, one of them mutably
# EXPECT-MATCH: aliasing values passed mutably to 'dest'
# Claim (3.11): subspans keep the parent's origin, so the checker sees two
# halves of one List as the same memory, even when they do not overlap.


def mirror(dest: Span[mut=True, Int, _], src: Span[Int, _]):
    for index in range(len(dest)):
        dest[index] = src[len(src) - 1 - index]


def main():
    var cells: List[Int] = [1, 2, 3, 4]
    var front = Span(cells)[0:2]
    var back = Span(cells)[2:4]
    mirror(front, back)
    print(cells)
```

[code/03-ownership/span_halves_one_call_fails.mojo](code/03-ownership/span_halves_one_call_fails.mojo)

When you need both halves in one call, recast one half's origin. The cast
asserts the invariant the checker cannot see: the halves do not overlap. It
also removes that half from lifetime tracking, so you must keep the owner
alive by other means; here `cells` has a later use:

```mojo
# Claims (3.11):
# - Recasting one half to `MutUntrackedOrigin` lets one call take both halves.
# - The cast removes that half from lifetime tracking, so the code keeps the
#   owner alive by using `cells` after the call. The halves do not overlap,
#   which is the invariant the cast asserts.
from std.testing import assert_equal


def mirror(dest: Span[mut=True, Int, _], src: Span[Int, _]):
    for index in range(len(dest)):
        dest[index] = src[len(src) - 1 - index]


def main() raises:
    var cells: List[Int] = [1, 2, 3, 4, 5, 6]
    var whole = Span(cells)
    var middle = len(whole) // 2
    var left = whole.unsafe_subspan(offset=0, length=middle)
    var right = Span(
        unsafe_ptr=whole.unsafe_ptr()
        .unsafe_offset(middle)
        .unsafe_origin_cast[MutUntrackedOrigin](),
        length=len(whole) - middle,
    )
    mirror(left, right)
    assert_equal(cells, [6, 5, 4, 4, 5, 6])
```

[code/03-ownership/span_split_with_untracked_half.mojo](code/03-ownership/span_split_with_untracked_half.mojo)

### Interior origins

Element references carry the container's *interior* origin, and a `mut self`
call on the container invalidates it. That rule reaches `ref` bindings and
pointers alike:

```mojo
# EXPECT-ERROR: an element reference used after a call that can reallocate the List
# EXPECT-MATCH: use of invalidated interior reference
# Claim (3.11): element references carry the List's interior origin, and a
# `mut self` call such as `append` invalidates that origin.


def main():
    var names: List[String] = ["ada", "grace"]
    ref first = names[0]
    names.append("linus")
    print(first)
```

[code/03-ownership/interior_reference_invalidated_fails.mojo](code/03-ownership/interior_reference_invalidated_fails.mojo)

```mojo
# EXPECT-ERROR: a Pointer to an element used after append
# EXPECT-MATCH: use of invalidated interior reference
# Claim (3.11): `Pointer(to=cells[0])` takes the element's interior origin, so
# invalidation reaches pointers as well as `ref` bindings.


def main():
    var cells: List[Int] = [1, 2, 3, 4]
    var head = Pointer(to=cells[0])
    cells.append(5)
    print(head[])
```

[code/03-ownership/pointer_to_element_invalidated_fails.mojo](code/03-ownership/pointer_to_element_invalidated_fails.mojo)

A `mut self` call never invalidates field references this way: a field sits at a fixed place
inside its struct, while interior storage moves when the container
reallocates. The stdlib builds interior origins with
`origin_of(self)._get_owned_interior["element"]` and
`Pointer._get_ref_with_unsafe_interior_origin`. Both carry an underscore:
they are private and experimental, so a library outside the stdlib cannot rely
on them yet.
