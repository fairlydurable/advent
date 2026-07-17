# Process text into data 🔥

A puzzle hands you text and wants answers in numbers. This page turns a raw
temperature log into typed values you can add up, rejecting the junk lines the
way real input always forces you to.

## Create the input

For a moment, you're going to be the Advent of Code creators and build a
data file for testing.

Create `parse_log.mojo`. Write a small temperature log to `temps.txt`:

```mojo
from std.pathlib import Path

def main() raises:
    var log = Path("temps.txt")

    log.write_text(
        String.write(
            "20.5",
            " 22.3",
            "",
            "19.8  ",
            "not a number",
            "26.0",
            "25.1",
            sep="\n",
            end="\n",
        )
    )

    print(log.read_text())
```

The file contains seven lines:

- three clean readings
- two readings with surrounding whitespace
- one blank line
- one invalid value

### Checkpoint

- `String.write()` joins `Writable` values into a `String`.
- The `sep` argument places a newline between values.
- The `end` argument adds a final newline.
- `write_text()` creates the file or replaces its existing contents.

### Other ways to create the input

<details>
<summary>Triple-quoted string</summary>

Triple-quoted strings preserve line breaks. Keep the content aligned to the
left to avoid adding indentation to the file:

<pre>
from std.pathlib import Path

def main() raises:
    var log = Path("temps.txt")

    log.write_text("""20.5
 22.3

19.8  
not a number
26.0
25.1
""")

    print(log.read_text())
</pre>

</details>

<details>
<summary>Adjacent string literals</summary>

Mojo combines adjacent string literals. You must add the newline escapes
yourself:

<pre>
from std.pathlib import Path

def main() raises:
    var log = Path("temps.txt")

    log.write_text(
        "20.5\n"
        " 22.3\n"
        "\n"
        "19.8  \n"
        "not a number\n"
        "26.0\n"
        "25.1\n"
    )

    print(log.read_text())
</pre>

</details>

<details>
<summary>Run-time strings</summary>

Build the content from run-time `String` values:

<pre>
from std.pathlib import Path

def main() raises:
    var log = Path("temps.txt")

    var values = Span([
        "20.5",
        " 22.3",
        "",
        "19.8  ",
        "not a number",
        "26.0",
        "25.1",
    ])

    log.write_text("\n".join(values) + "\n")
</pre>

Easy to extend, but you must add the final newline yourself.

</details>

## Splitting lines

When your puzzle needs you to process a line at a time, split
your data into separate lines:

```mojo
var text = log.read_text()
var lines = text.splitlines()
print(t"Got {len(lines)} lines") # Got 7 lines
```

### Checkpoint

- `splitlines()` returns a `List[StringSlice]`.
- Each slice refers to data owned by `text`, so keep `text` alive while
  using the slices.
- `splitlines()` handles `\n`, `\r\n`, and `\r`.
- It doesn't return an extra empty line for the final newline.
- For other separators, use `split(sep)`.

### Try this

Replace:

```mojo
text.splitlines()
```

with:

```mojo
text.split("\n") # Got 8 lines
```

The final newline becomes an extra empty element. For line-oriented text,
prefer `splitlines()`:

## Tidy your input

To get your puzzle solved, you'll often need to strip whitespace
and skip blank lines:

```mojo
for line in lines:
    var cleaned = line.strip()
    if not cleaned:
        continue
    print(t"line: '{cleaned}'")
```

Six cleaned entries, and your blank line is skipped.

### Checkpoint

- `strip()` returns a `StringSlice` with leading and trailing whitespace
  removed.
- Use `lstrip()` or `rstrip()` to clean only one side.
- Empty strings and string slices are false in conditional expressions.
- `continue` skips the rest of the current iteration.
- `break` exits the loop entirely.

## Type conversion

While your puzzle input is text, your data often won't be:

```mojo
var temps: List[Float64] = []  # Explicitly type this empty list

for line in lines:
    var cleaned = line.strip()
    if not cleaned:
        continue

    temps.append(Float64(cleaned))

print(t"Parsed {len(temps)} temperatures: {temps}")
```

When you run this, the program stops at `not a number`. Oops.

### Checkpoint

- `Float64(value)` raises when the text isn't a valid floating-point value.
- `append()` adds a value to the end of a list.

## Handle invalid lines

Catch conversion errors and keep parsing:

```mojo
var temps: List[Float64] = []
var rejected: List[String] = []

for line in lines:
    var cleaned = line.strip()
    if not cleaned:
        continue

    try:
        temps.append(Float64(cleaned))
    except:
        rejected.append(String(cleaned))

print(t"Parsed {len(temps)} temperatures: {temps}")
print(t"Rejected {len(rejected)}: {rejected}")
```

Five parsed readings and one rejected value.

### Checkpoint

- On failure, skip, record, replace, or stop.
- The rejected list stores `String` copies rather than views into `text`.

### Try this

`except:` catches and discards the error. Use `except e:` to inspect the
error.

Change `except` to `except e` and then print the error with the rejected
line:

```mojo
except e:
    print(t"Rejected '{cleaned}': {e}")
    rejected.append(String(cleaned))
```

## Clean up

To remove the temporary file, add this import:

```mojo
from std.os import remove
```

Then call `remove(log)` at the end of `main()`.

## Final code

Your complete `parse_log.mojo`:

```mojo
from std.pathlib import Path
from std.os import remove

def main() raises:
    var log = Path("temps.txt")

    log.write_text(
        String.write(
            "20.5",
            " 22.3",
            "",
            "19.8  ",
            "not a number",
            "26.0",
            "25.1",
            sep="\n",
            end="\n",
        )
    )

    var text = log.read_text()
    var lines = text.splitlines()
    print(t"Got {len(lines)} lines")

    var temps: List[Float64] = []
    var rejected: List[String] = []

    for line in lines:
        var cleaned = line.strip()
        if not cleaned:
            continue

        try:
            temps.append(Float64(cleaned))
        except:
            rejected.append(String(cleaned))

    print(t"Parsed {len(temps)} temperatures: {temps}")
    print(t"Rejected {len(rejected)}: {rejected}")

    remove(log)
```

## What you touched

Reading and writing text files, `splitlines()`, `strip()`, string truthiness,
value iteration, `continue`, typed lists, `append()`, conversion to
`Float64`, and error handling.

## Also worth knowing

**Comma-separated lines**:

For a simple row like: `Mon, 20.5`, split the line into columns:

```mojo
var columns = line.split(",")
```

**Preserving line endings**:

Use `splitlines(keepends=True)` to preserve each line's `\n` or `\r\n`.
This is useful when rewriting a file while keeping its original line-ending
style.
