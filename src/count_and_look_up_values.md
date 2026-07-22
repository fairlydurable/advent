# Count and look up values 🔥

Working with collections is core to Advent of Code puzzles. Understanding
and using lists, dictionaries, sets, and tuples helps you reach solutions.

## Your puzzle

You just got handed a puzzle with a pile of station reports. "Which stations
went quiet?"

Here's what you need: tally repeats (a great match to dictionaries),
membership tests (perfect for sets), and compound keys (tuples are a good
choice).

### The situation report

You already parsed the log, so every reading now carries its station id.
You've already lined them up as a plain list, repeats and all:

Create `reports.mojo`:

```mojo
def main() raises:
    # each reading's station id, already parsed from the log
    var reported_ids = [3, 1, 3, 5, 1, 3, 1, 5, 1, 5, 5, 3, 5, 5, 1]
    print(t"{len(reported_ids)} readings")  # 15 readings
```

You need to turn that raw list into answers.

## Tally with a dictionary

How many times did each station report? Time to use a dictionary.

A `Dict` maps keys to values. To count, use each station id as a key and
bump its running total. Add this to `main()`:

```mojo
var counts = Dict[Int, Int]()
for id in reported_ids:
    counts[id] = counts.get(id, 0) + 1
    # Key not found? Count defaults to 0.

for entry in counts.items():
    print(t"station {entry.key}: {entry.value} readings")
```

Here's the output. The counts won't vary but the order may, as
dictionaries are not ordered collections:

```mojo
station 3: 4 readings
station 1: 5 readings
station 5: 6 readings
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
- Dictionaries don't provide an order guarantee.

## Look up fast with a set

A `Set` is a collection of unique items. It contains each value once and
only once, answering "is this value in here or not?"

Build the set of stations that reported.

Sets aren't part of Mojo's automatic imports (the "prelude") so add this
import to the top of your file.

```mojo
from std.collections import Set
```

Then add this to `main()`:

```mojo
var reported: Set[Int] = {}
for id in reported_ids:
    reported.add(id)

for station in range(1, 6):
    print(t"Station {station} reported? "  # TStrings allow concatenation
            t"{"Yes" if station in reported else "No"}")
# Station 1 reported? Yes
# Station 2 reported? No
# Station 3 reported? Yes
# Station 4 reported? No
# Station 5 reported? Yes
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
var expected = Set[Int](1, 2, 3, 4, 5)
var missing = expected - reported
print(t"silent stations: {missing}")  # {2, 4} in either order
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
var per_day = Dict[Tuple[Int, Int], Int]()
var log = [(3, 0), (3, 0), (1, 2), (3, 1)]  # (station, day)
for pair in log:
    per_day[pair] = per_day.get(pair, 0) + 1

for entry in per_day.items():
    var station, day = entry.key  # unpack the tuple key
    print(t"station {station}, day {day}: {entry.value}")
```

Dictionary keys must be hashable, and integer tuples fit that requirement.

### Checkpoint

- A `Tuple` groups a fixed set of values. If its entries are hashable, you
  can use them as dictionary keys. `(station, day)` counts each pair on its
  own.
- `var station, day = entry.key` unpacks a tuple into named bindings in
  one step.
- Reach for compound keys whenever "per X" quietly becomes "per X and Y".

## Comprehensions: smart data retrieval

Now imagine your data set looks like this:

```mojo
var data = [(1, 0), (1, 0), (1, 0), (2, 0), (2, 0), (3, 0),
            (3, 0), (3, 0), (1, 1), (3, 1), (3, 1), (3, 1),
            (3, 1), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2),
            (1, 2), (2, 2), (2, 2), (3, 2), (3, 2), (3, 2),
            (3, 2)]
```

Each entry in the `data` list uses the same tuple form as before, but
in this puzzle, you have only three stations to work with.

Your job is to find the stations that didn't report and which day they
went silent.

Instead of unpacking the tuples, build a set:

```mojo
var per_day_set: Set[Tuple[Int, Int]] = {}
for pair in data:
    per_day_set.add(pair)
```

Mojo comprehensions let you iterate and filter results in one expression:

```mojo
var missing_days = [String(t"Station {station} - Day {day}")
    for station in range(1, 4)
    for day in range(3)
    if (station, day) not in per_day_set
]
```

In this example, missing_days iterates over each combination of `station`
and `day`, selecting only those items that don't appear in the set.

The result? Station 2 failed to report on day 1. Because your days use
zero-indexing, that's the second day:

```mojo
print(t"missing days: {missing_days}")  # ['Station 2 - Day 1]'
```

Remove `(1, 1)` from your data to add another item to missing days.

## Final code

Your complete `reports.mojo`:

```mojo
from std.collections import Set

def main() raises:
    # each reading's station id, already parsed from the log
    var reported_ids = [3, 1, 3, 5, 1, 3, 1, 5, 1, 5, 5, 3, 5, 5, 1]
    print(t"{len(reported_ids)} readings")  # 15

    var counts = Dict[Int, Int]()
    for id in reported_ids:
        counts[id] = counts.get(id, 0) + 1

    for entry in counts.items():
        print(t"station {entry.key}: {entry.value} readings")

    var reported: Set[Int] = {}
    for id in reported_ids:
        reported.add(id)

    for station in range(1, 6):
        print(t"Station {station} reported? "  # TStrings allow concatenation
                t"{"Yes" if station in reported else "No"}")
    # Station 1 reported? Yes
    # Station 2 reported? No
    # Station 3 reported? Yes
    # Station 4 reported? No
    # Station 5 reported? Yes

    var expected = Set[Int](1, 2, 3, 4, 5)
    var missing = expected - reported
    print(t"silent stations: {missing}")  # {2, 4}

    var per_day = Dict[Tuple[Int, Int], Int]()
    var log = [(3, 0), (3, 0), (1, 2), (3, 1)]  # (station, day)
    for pair in log:
        per_day[pair] = per_day.get(pair, 0) + 1

    for entry in per_day.items():
        var station, day = entry.key  # unpack the tuple key
        print(t"station {station}, day {day}: {entry.value}")

    # Try removing (1, 1) after running the missing days code below
    var data = [(1, 0), (1, 0), (1, 0), (2, 0), (2, 0), (3, 0),
                (3, 0), (3, 0), (1, 1), (3, 1), (3, 1), (3, 1),
                (3, 1), (1, 2), (1, 2), (1, 2), (1, 2), (1, 2),
                (1, 2), (2, 2), (2, 2), (3, 2), (3, 2), (3, 2),
                (3, 2)]

    var per_day_set: Set[Tuple[Int, Int]] = {}
    for pair in data:
        per_day_set.add(pair)

    var missing_days = [String(t"Station {station} - Day {day}")
        for station in range(1, 4)
        for day in range(3)
        if (station, day) not in per_day_set
    ]

    print(t"missing days: {missing_days}")  # ['Station 2 - Day 1']
```

## What you touched

Dictionaries as counters, `get()` with a default, iterating `items()`, sets
for uniqueness and fast membership, set differences, tuples as compound
keys, tuple unpacking, and comprehensions for generating and filtering
combinations
