# Pull numbers from text 🔥

<!-- markdownlint-disable MD024 -->

Advent of Code puzzles often require you to extract numbers from text files. You
typically need to find the numbers, separate out the ones you want,
and turn them into values you can compute with. This page returns
to the sensor log from [Work with files](./work_with_files.md).

## Scan for the numbers

Create `pull_numbers_from_text.mojo`. You can collect digit runs by walking
text a byte at a time. Add this function above `main()`:

```mojo
{{#include ../snippets/pull_numbers_from_text/pull_numbers_from_text.mojo:extract_ints}}
```

### Checkpoint

- The scan groups adjacent digits into runs. `20` stays one number
  instead of a `2` and a `0`.
- `extract_ints()` raises because `Int(text)` can raise on bad input.
- Return the newly constructed `List` with `^` to transfer ownership of its
  data to the caller instead of copying it.
- `String(text[byte=i])` reads a single byte. Using `text[i]` is an error.
  The string constructor converts the byte back to a string. In ASCII,
  the bytes from 48 through 57 represent the digits 0 through 9.

Read the log and run the scan over the whole thing:

```mojo
{{#include ../snippets/pull_numbers_from_text/pull_numbers_from_text.mojo:read_log}}
```

```mojo
{{#include ../snippets/pull_numbers_from_text/pull_numbers_from_text.mojo:call_extract}}
```

Every day, temperature, and condition got flattened into one long run of
integers, with no idea which numbers belong together.

## Which numbers do you want?

You know the shape of each line: day number, whole-degree part, tenths
digit, three numbers per line. Take every third value to pull out just the
day numbers:

```mojo
{{#include ../snippets/pull_numbers_from_text/pull_numbers_from_text.mojo:filter_by_shape}}
```

### Checkpoint

- `range(0, len(found), 3)` walks every third index. Extraction finds
  candidates; you pick the ones that matter based on the input's shape.

## Check your work

A log with ten entries should number its days 1 through 10, in order, with
nothing missing or duplicated. Build the sequence you expect and compare:

```mojo
{{#include ../snippets/pull_numbers_from_text/pull_numbers_from_text.mojo:validate_sequence}}
```

### Checkpoint

- An invariant you can derive from the input, like a complete day count,
  gives you a free correctness check. Reach for it before you trust a
  parse.
- This is the same move on puzzle input: parse, then confirm against
  something the shape of the input already promises you.

## Push it: a reading with a decimal

Digit-run scanning is effective for whole numbers, but not for a values carrying
a sign or a decimal point:

```mojo
{{#include ../snippets/pull_numbers_from_text/pull_numbers_from_text.mojo:decimal_breaks}}
```

`-20.5` comes back as `[1, 20, 5]`. The minus sign vanishes and the dot
ends the run early, splitting one reading into two numbers.

For a real reading, switch techniques: split the line into fields and
parse the one you want.

```mojo
{{#include ../snippets/pull_numbers_from_text/pull_numbers_from_text.mojo:decimal_reading}}
```

Because you know the temperature field is a signed decimal followed by
`"C"`, it's safe to remove the unit before parsing.

### Checkpoint

- Match the tool to the data. A digit scan extracts whole numbers from
  prose. A field split isolates a value in a known position, sign and all.
- `split(sep)` returns a `List[StringSlice]`, each slice a view into the
  original text. Convert a slice to `String` when you need to create or
  modify owned text.
- `Float64(text)` raises on anything that isn't a number, the same as
  `Int(text)`.

## Final code

Your complete `pull_numbers_from_text.mojo`:

```mojo
{{#include ../snippets/pull_numbers_from_text/pull_numbers_from_text.mojo:final}}
```

## Topics Covered

Byte-by-byte string scanning, digit runs, `Int` and `Float64` parsing,
`raises` propagation, returning a `List` with `^`, stride-based filtering,
validating a parse against an invariant the input's shape promises, and
splitting into fields.

<!-- markdownlint-enable MD024 -->
