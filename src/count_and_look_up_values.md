# Count and look up values 🔥

<!-- markdownlint-disable MD024 -->

<div class="intro">
  <div class="intro-text">

Working with collections is core to Advent of Code puzzles. Understanding
and using lists, dictionaries, sets, and tuples helps you reach solutions.

> [!NOTE]
> Advent of Mojo is a work in progress. Content, examples, and structure
> may change. If you've found a bug, have a suggestion, or want to flag
> something confusing, or any other reason, please open a thorough
> ***Documentation*** issue on the
> [Modular GitHub](https://github.com/modular/modular/issues).
>
> This link may change when Advent is broken off to its own repository.

  </div>

  <div class="intro-image">
    <img
      class="intro-image-light"
      src="img/tally-light.png"
      alt="Mojo tallying data."
    >
    <img
      class="intro-image-dark"
      src="img/tally-dark.png"
      alt="Mojo tallying data."
    >
  </div>
</div>

## Your puzzle

You just got handed a puzzle with a pile of station reports. You need to
identify which stations went quiet.

Here's what you'll need: tallys (a great match to dictionaries),
membership tests (perfect for sets), and compound keys (tuples are a good
choice).

### The situation report

Download [station_reports.txt](./downloads/station_reports.txt). Every line
names a station and the day it reported, arriving out of order with
repeats, the way a real batch of sensor uploads would:

Create `count_and_look_up_values.mojo`, and read the reports:

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:reports}}
```

You need to turn that raw list into answers.

## Tally with a dictionary

How many times did each station report? Time to use a dictionary.

A `Dict` maps keys to values. To count, use each station id as a key and
bump its running total. Add this to `main()`:

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:tally}}
```

Station 1 reported five times, station 3 four times, and station 5 six
times. Two stations never show up at all.

### Checkpoint

- `Dict[K, V]` needs a key type and a value type. The stations are numbered
  and so are their repetitions, so this is a `Dict[Int, Int]`.
- `counts.get(id, 0)` returns the stored count, defaulting to `0` for
  absent keys. That default is what makes the counter work on a station's
  first reading.
- `counts.items()` walks the pairs. Each `entry` carries `entry.key` and
  `entry.value`.
- Dictionaries don't provide an order guarantee. Sort the entries yourself
  before printing them if you need a stable order.

## Look up fast with a set

A `Set` is a collection of unique items. It contains each value once and
only once, answering "is this value in here or not?"

Build the set of stations that reported.

Sets aren't part of Mojo's automatic imports (the "prelude") so add this
import to the top of your file.

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:import_set}}
```

Then add this to `main()`:

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:lookup_set}}
```

Did station 1 report? Yes. Did station 2? No.

### Checkpoint

- Mojo collections are part of the `std.collections` package.
- With a set, `add` is idempotent. Adding a station that's already present
  changes nothing, which is how the set collapses the repeats down to three
  distinct ids.
- `x in set` is the membership test. On a list you'd scan every element.
  In a dictionary, you'd have to look at the keys or check for a failed
  lookup. A set answers "is this here?" directly.

## Who went silent

You know the roster you expected to hear from. Subtract the ones that reported
and the silent stations fall out.

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:silent_stations}}
```

Like dictionaries, sets are not ordered, so you may see "{4, 2}".

### Checkpoint

- Both dictionary and set literals use curly braces. Sets don't use colons.
  Dictionaries do. `{"a", "b"}` is a set literal and `{"a": 5, "b": 3}` is a
  dictionary literal.
- `-` is set difference: everything in `expected` that isn't in `reported`.
- `&` is intersection (in both collections) and `|` is union (in either).
- Like checking a count against a total, your set checks coverage against
  an expected roster. Same instinct, one level up: confirm you have
  everything you should.

## Tuples: Mojo's anonymous types

One key isn't always enough. To count readings per station *and* day, key the
dictionary on a tuple.

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:tuple_keys}}
```

Dictionary keys must be hashable, and integer tuples fit that requirement.

### Checkpoint

- A `Tuple` groups a fixed set of values. If its entries are hashable, you
  can use them as dictionary keys. `(station, day)` counts each pair on its
  own.
- `var station, day = entry.key` unpacks a tuple into named bindings in
  one step.
- Reach for compound keys whenever "per X" becomes "per X and Y".

## Comprehensions: smart data retrieval

Stations 2 and 4 never reported at all. The remaining question is narrower:
among the three stations that did report, did any of them miss a day?

Build a set of the `(station, day)` pairs that actually showed up:

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:build_set}}
```

Mojo comprehensions let you iterate and filter results in one expression:

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:comprehension}}
```

`missing_days` iterates over every combination of `station` and `day`
across the three reporting stations, selecting only the pairs that never
appear in `per_day_set`.

The result: station 1 never reported on day 1.

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:print_missing}}
```

## Final code

Your complete `count_and_look_up_values.mojo`:

```mojo
{{#include ../snippets/count_and_look_up_values/count_and_look_up_values.mojo:final}}
```

## Topics covered

Dictionaries as counters, `get()` with a default, iterating `items()`, sets
for uniqueness and fast membership, set differences, tuples as compound
keys, tuple unpacking, and comprehensions for generating and filtering
combinations.

<!-- markdownlint-enable MD024 -->
