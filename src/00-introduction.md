# Introduction

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- VERIFIED: Mojo/stdlib/std/traits/anytype.mojo, Mojo/stdlib/std/traits/deinitable.mojo, Mojo/stdlib/std/memory/alloc.mojo -->

What the Mojonomicon covers, who it's for, and how to run and check its samples.

## About this book

The Mojonomicon covers the parts of Mojo that ordinary programs never see:
raw memory, uninitialized storage, origins, linear types, layout, foreign
calls, and the rules that keep them sound. Its outline follows the
Rustonomicon chapter for chapter, so a reader who knows that book can find
the matching topic here. The content teaches Mojo's own model. Where Mojo has
no counterpart to a Rustonomicon section, the section says so and covers the
Mojo mechanism that fills the same role.

The book assumes an experienced systems programmer who builds containers,
allocators, smart pointers, or bindings, and who needs to know exactly what
the compiler checks and what it leaves to them.

This book covers the dark corners. Most Mojo code never needs `alloc`,
`unsafe_write`, or an origin cast, and code that reaches for them takes on
obligations the compiler can no longer check. Read the safety notes as
contracts.

## Two ideas to hold onto

Mojo destroys a value right after its last use, not at the end of its scope.
Every chapter leans on this rule, so it opens the book:

```mojo
# Claim: Mojo destroys a value right after its last use, not at the end of
# the enclosing scope.
# Claim: `deinit(value^)` extends a value's lifetime to that exact point.
from std.testing import assert_equal


struct Valve[origin: MutOrigin]:
    var name: String
    var events: Pointer[List[String], Self.origin]

    def __init__(out self, name: String, ref[Self.origin] events: List[String]):
        self.name = name
        self.events = Pointer(to=events)
        self.events[].append("open " + name)

    def __deinit__(deinit self):
        self.events[].append("close " + self.name)


def main() raises:
    var events = List[String]()

    var intake = Valve("intake", events)
    var exhaust = Valve("exhaust", events)
    # `intake` has no use after its construction, so it closed before
    # `exhaust` opened.
    assert_equal(events[1], "close intake")
    assert_equal(events[2], "open exhaust")

    events.append("checkpoint")
    deinit(exhaust^)  # Keeps `exhaust` alive until this line.
    assert_equal(events[3], "checkpoint")
    assert_equal(events[4], "close exhaust")
    print("events:", len(events))  # events: 5
```

[code/00-introduction/asap_destruction.mojo](code/00-introduction/asap_destruction.mojo)

The second idea: a type can refuse implicit destruction. `alloc` returns an
`Allocation`, a linear value that every path must hand to `dealloc` (or
explicitly leak). Forgetting it is a compile error, not a leak:

```mojo
# EXPECT-ERROR: an Allocation is a linear value; dropping it without dealloc is a compile error
# EXPECT-MATCH: abandoned without being explicitly destroyed
# Claim: the compiler rejects a heap allocation that no path releases.
from std.memory import alloc, Layout


def main():
    var samples = alloc(Layout[Float64](length=256))
    print("reserved", len(samples), "samples")
```

[code/00-introduction/abandoned_allocation_fails.mojo](code/00-introduction/abandoned_allocation_fails.mojo)

## The compiler behind the samples

The samples and claims in this book pass on Mojo 1.3.0.dev0, built from the
Modular repository's main branch at commit `c3da0ac4bbf` on 2026-11-11.
Mojo's low-level APIs move fast: `Pointer` with `unsafe_`-prefixed methods,
`alloc(Layout[T](length=n))`, `__deinit__`, and `not Deinitable` replaced
`UnsafePointer`, `alloc[T](count)`, `__del__`, and `@explicit_destroy`. Older books, blog posts, and models
trained on them use names that no longer compile. When a sample here and an
older source disagree, run the sample.

## Running the samples

Each sample lives in its own file under `src/code/`, in a directory named after
its chapter. A sample opens with comments that state the claims it proves,
and it proves them with `std.testing` asserts rather than printed output.

To check every sample with the repository's Pixi environment, run
`pixi run test` from the book's root directory. To check them with another
compiler:

1. Point the `MOJO` environment variable at the `mojo` binary you want to
   test. It defaults to the `mojo` on your `PATH`.
2. Run `./run_samples.sh` from the book's root directory, or pass one or
   more chapter directories under `src/code/` to check only those.
3. Read the summary line. The script prints each failure with the first lines
   of compiler or program output, and exits nonzero if any sample fails.

The script reads a contract from each file's header comments:

| Marker | Contract |
|---|---|
| none | Compiles, runs, and exits 0. |
| `# EXPECT-ERROR: <gist>` | Fails to compile. The gist says why. |
| `# EXPECT-MATCH: <regex>` | With `EXPECT-ERROR`, the compiler output matches this extended regex, so the sample fails for the stated reason. |
| `# EXPECT-EXIT: nonzero` | Compiles, then exits nonzero at run time, such as on a bounds-check abort. |

No sample in `src/code/` executes undefined behavior. When a chapter needs to
show undefined behavior, it uses a short snippet in the text, labels it, and
never shows what it printed.
