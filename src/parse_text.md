# Process text into data 🔥

<!-- markdownlint-disable MD024 -->

<div class="intro">
  <div class="intro-text">

A puzzle hands you text and wants answers in numbers. This page returns to
the sensor log from [Work with files](./work_with_files.md) and
[Work with strings](./work_with_strings.md), and turns it into typed values
you can add up, rejecting the junk lines the way real input always forces
you to.

  </div>

  <div class="intro-image">
    <img
      class="intro-image-light"
      src="img/typed-data-light.png"
      alt="Mojo casting numbers."
    >
    <img
      class="intro-image-dark"
      src="img/typed-data-dark.png"
      alt="Mojo casting numbers."
    >
  </div>
</div>

## Splitting lines

Create `parse_text.mojo`, and split the log into separate lines, the same
way you did in
[Work with files](./work_with_files.md#split-into-lines):

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:read_lines}}
```

### Try this

Replace `splitlines()` with `split("\n")`:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:split_vs_splitlines}}
```

The final newline becomes an extra empty element: 11 entries instead of 10.
For line-oriented text, prefer `splitlines()`.

## Tidy your input

Some of Chiller's lines carry stray leading or trailing whitespace. Strip
each line, skip anything blank, and save the result in `cleaned_lines` so
every step from here on works with tidy data instead of stripping again
each time:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:strip_and_skip}}
```

### Checkpoint

- `strip()` returns a `StringSlice` with leading and trailing whitespace
  removed.
- Use `lstrip()` or `rstrip()` to clean only one side.
- Empty strings and string slices are false in conditional expressions.
- `continue` skips the rest of the current iteration.
- Wrapping each cleaned slice in `String(...)` copies it out of `text`, so
  `cleaned_lines` stays valid on its own.

## Extract the fields

Each line packs three pieces of information into one string: the day, the
temperature, and the conditions. Split on the same separators the log
uses to pull them apart:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:extract_fields}}
```

### Checkpoint

- `split(sep)` returns a `List[StringSlice]`, a view into the original text.
- Chaining `split()` calls peels off one layer of structure at a time.

## Type conversion

The temperature field still carries its unit. Try converting it directly:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:naive_float_fails}}
```

`Float64()` raises. The trailing `C` isn't part of the number.

Strip the unit first:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:strip_units}}
```

### Checkpoint

- `Float64(value)` raises when the text isn't a valid floating-point value.
- `removesuffix(suffix)` strips the substring only if it appears at the end,
  and returns the text unchanged otherwise.

## Collect all readings

Put the extraction and conversion together for every line in
`cleaned_lines`:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:convert_to_float}}
```

Ten parsed readings.

### Checkpoint

- `append()` adds a value to the end of a list.
- Typed lists like `List[Float64]` catch mismatched values at compile time.

## Handle invalid lines

Sensors fail. Copy `cleaned_lines` and simulate one more reading coming in
corrupted:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:inject_bad_reading}}
```

Catch conversion errors and keep parsing instead of crashing:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:handle_invalid}}
```

Ten parsed readings and one rejected value.

### Checkpoint

- On failure, skip, record, replace, or stop.
- The rejected list stores `String` copies rather than views into the
  original line.

### Try this

`except:` catches and discards the error. Use `except e:` to inspect the
error.

Change `except` to `except e` and then print the error with the rejected
line:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:except_with_error}}
```

## Final code

Your complete `parse_text.mojo`:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:final}}
```

## Topics covered

Splitting text, stripping whitespace, chained field extraction, string
truthiness, `continue`, typed lists, `append()`, conversion to `Float64`,
`removesuffix()`, and error handling.

## Also worth knowing

**Comma-separated columns**:

A naive `split(",")` doesn't clean up whitespace around the separator.
Chiller's foggy day has extra spaces after the comma:

```mojo
{{#include ../snippets/parse_text/parse_text.mojo:split_columns}}
```

Strip each column afterward if that matters for your puzzle.

**Preserving line endings**:

Use `splitlines(keepends=True)` to preserve each line's `\n` or `\r\n`.
This is useful when rewriting a file while keeping its original line-ending
style.

<!-- markdownlint-enable MD024 -->
