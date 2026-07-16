# Process text into data 🔥

A puzzle hands you text and wants answers in numbers. This page turns a raw
temperature log into typed values you can add up, rejecting the junk lines the
way real input always forces you to.

## Create the input

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

## Split the text into lines

Read the file and split it into lines:

```mojo
var text = log.read_text()
var lines = text.splitlines()
print(t"Got {len(lines)} lines")
```

Run it again:

```text
Got 7 lines
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
text.split("\n")
```

Run the program again. You should see:

```text
Got 8 lines
```

The final newline becomes an extra empty element. For line-oriented text,
prefer `splitlines()`.

## Clean up text

Strip whitespace and skip blank lines:

```mojo
for line in lines:
    var cleaned = line.strip()
    if not cleaned:
        continue
    print(t"line: '{cleaned}'")
```

Run it. You should see six cleaned entries. The blank line is skipped.

### Checkpoint

- `strip()` returns a `StringSlice` with leading and trailing whitespace
  removed.
- Use `lstrip()` or `rstrip()` to clean only one side.
- Empty strings and string slices are false in conditional expressions.
- `continue` skips the rest of the current iteration.
- `break` exits the loop entirely.

## Type conversion

Convert each line to `Float64`:

```mojo
var temps: List[Float64] = []

for line in lines:
    var cleaned = line.strip()
    if not cleaned:
        continue

    temps.append(Float64(cleaned))

print(t"Parsed {len(temps)} temperatures: {temps}")
```

Run it. The program stops at:

```text
not a number
```

### Checkpoint

- `Float64(value)` raises when the text isn't a valid floating-point value.
- `append()` adds a value to the end of a list.
- An empty list literal needs an explicit element type:

```mojo
var temps: List[Float64] = []
```

Without the type, Mojo can't determine what the list should contain.

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

Run the program. You should see five parsed readings and one rejected value.

### Checkpoint

- On failure, skip, record, replace, or stop.
- `except:` catches and discards the error.
- Use `except e:` to inspect the error.
- The rejected list stores `String` copies rather than views into `text`.

### Try this

Change:

```mojo
except:
```

to:

```mojo
except e:
```

Then print the error with the rejected line:

```mojo
except e:
    print(t"Rejected '{cleaned}': {e}")
    rejected.append(String(cleaned))
```

The full parse error is useful while you're debugging an input format.

## Compute an average

Compute the average:

```mojo
if len(temps) == 0:
    print("No usable readings")
else:
    var total: Float64 = 0.0

    for temp in temps:
        total += temp

    var average = total / Float64(len(temps))
    print(t"Average of {len(temps)} readings: {average}")
```

Run it:

```text
Average of 5 readings: 22.74
```

### Checkpoint

- `Float64(value)` raises on invalid input.
- Check for an empty list before dividing by its length.
- `for temp in temps:` iterates over values.
- `Float64(len(temps))` converts the count before division.
- Mojo doesn't silently widen integer values to floating-point values.

## Clean up

Remove the temporary file:

Add this import:

```mojo
from std.os import remove
```

Then add this at the end of `main()`:

```mojo
remove(log)
```

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

    if len(temps) == 0:
        print("No usable readings")
    else:
        var total: Float64 = 0.0

        for temp in temps:
            total += temp

        var average = total / Float64(len(temps))
        print(t"Average of {len(temps)} readings: {average}")

    remove(log)
```

## What you touched

Reading and writing text files, `splitlines()`, `strip()`, string truthiness,
value iteration, `continue`, typed lists, `append()`, conversion to
`Float64`, per-value error handling, defensive empty-list checks, and
explicit numeric conversion.

## Also worth knowing

**Integers**:

`Int(value)` parses text into an `Int` and raises on invalid input.

Use `atol(value, base)` when you need to select a base:

```mojo
atol("FF", 16)
atol("0xFF", 0)
```

A base of `0` detects prefixes such as `0x`.

**Comma-separated lines**:

For a simple row such as:

```text
Mon, 20.5
```

split the line into columns:

```mojo
var columns = line.split(",")
```

Strip each column before converting it. The same per-value `try`/`except`
pattern applies.

**Preserving line endings**:

Use:

```mojo
splitlines(keepends=True)
```

to preserve each line's `\n` or `\r\n`. This is useful when rewriting a file
while keeping its original line-ending style.
