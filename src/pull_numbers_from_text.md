# Pull numbers from text 🔥

Your puzzle buried the numbers inside a sentence and wants them back as a
clean list. Here's what you need: find the numbers in a line of prose,
separate the ones you want from the ones you don't, and turn them into
values you can compute with.

## The line

Create `numbers.mojo`. The overnight batch from Station 3 arrived in text,
not as CSV or a table:

```mojo
def main():
    var line: String = "Station 3:\n"
        "  Readings per day this week (M-F): 2, 6, 3, 4, and 5.\n"
        "  (20 readings total)."
    print(line)
```

The five daily counts are in there, tangled up with two numbers you don't
want.

### Checkpoint

Strings on adjacent lines or on the same line automatically concatenate:

```mojo
var x = "Hello, " "World"
print(x)  # Hello, World
```

## Scan for the numbers

You can collect digit runs by walking the line a byte at a time. All the
values are integers, so collect each digit run and convert it to `Int`.

Add this function above `main()`:

```mojo
def extract_ints(text: String) raises -> List[Int]:
    var nums = List[Int]()
    var cur = String("")
    for i in range(text.byte_length()):
        var c = String(text[byte=i])
        if c >= "0" and c <= "9":  # an ASCII digit
            cur += c               # extend the current run
        elif cur:                  # a run just ended
            nums.append(Int(cur))
            cur = String("")
    if cur:                        # a run at the very end
        nums.append(Int(cur))
    return nums^
```

Call it from `main()` and print what comes back:

```mojo
    var found = extract_ints(line)
    print(t"found: {found}")  # [3, 2, 6, 3, 4, 5, 20]
```

### Checkpoint

- The scan groups adjacent digits into runs. `20` stays one number
  instead of a `2` and a `0`.
- `extract_ints()` raises because `Int(text)` can raise on bad
  input.
- Return the newly constructed `List` with ^ to transfer ownership of its
  data to the caller instead of copying it.
- `String(text[byte=i])` reads a single byte. Using `text[i]` is an error.
  The string constructor converts the byte back to a string. In ASCII,
  the bytes from 48 through 57 represent the digits 0 through 9.

## Which numbers do you want?

The scan grabbed everything including the station ID and stated total:
`[3, 2, 6, 3, 4, 5, 20]`.

You know the shape of the line, so drop the first (station ID) and the last
(checksum) numbers:

```mojo
var counts = List[Int]()
for i in range(1, len(found) - 1):  # skip station ID and total
    counts.append(found[i])
print(t"daily counts: {counts}")  # [2, 6, 3, 4, 5]
```

### Checkpoint

- `range(1, len(found) - 1)` walks the interior indices, the half-open
  range `[1, len - 1)`.
- Extraction finds candidates. You pick the candidates that matter.

## Check your work

The line also gives you a total: (20 readings total). You can use that as a
checksum. Add the daily counts and make sure the result agrees:

```mojo
var running_count = 0
for c in counts:
    running_count += c
var stated = found[len(found) - 1]
print(t"sum: {running_count}, stated total: {stated}")
print(t"match: {running_count == stated}")  # True
```

### Checkpoint

- A total embedded in the input gives you a free correctness check.
  Reach for it before you trust an answer.
- This is the same move on puzzle input: parse, then confirm against a
  number the input already gives you.

## Push it: a reading with a decimal

Digit-run scanning is built for whole numbers. It breaks the moment a value
carries a decimal point. A later line reads:

```text
Station 3, Monday, Reading 1: 22.1 C
```

Scan that for integers and `22.1` comes back as `22` and `1`, because the dot
ends the run. For a real reading, switch techniques: split the line into fields
and parse the one you want.

```mojo
var entry: String = "Station 3, Monday, Reading 1: 22.1 C"
var fields = entry.split(": ")  # ["Station 3, Monday, Reading 1", "22.1 C"]

var tail = fields[len(fields) - 1]  # "22.1 C"

# Clean up
var reading = Float64(String(tail).replace("C", "").strip())
print(t"reading: {reading}")        # 22.1
```

Because you know the final field contains a numeric value followed by "C",
it's safe to remove the unit and surrounding whitespace before parsing.

### Checkpoint

- Match the tool to the data. A digit scan extracts whole numbers from prose.
  A field split isolates a value in a known position.
- `split(sep)` returns a `List[StringSlice]`, each slice a view into the
  original text. Convert a slice to `String` when you need to create or
  modify owned text.
- `Float64(text)` raises on anything that isn't a number, the same as
  `Int(text)`.

## Final code

Your complete `numbers.mojo`:

```mojo
def extract_ints(text: String) raises -> List[Int]:
    var nums = List[Int]()
    var cur = String("")
    for i in range(text.byte_length()):
        var c = String(text[byte=i])
        if c >= "0" and c <= "9":  # an ASCII digit
            cur += c               # extend the current run
        elif cur:                  # a run just ended
            nums.append(Int(cur))
            cur = String("")
    if cur:                        # a run at the very end
        nums.append(Int(cur))
    return nums^


def main() raises:
    var line: String = "Station 3:\n"
        "  Readings per day this week (M-F): 2, 6, 3, 4, and 5.\n"
        "  (20 readings total)."
    print(line) # show the string

    var found = extract_ints(line)
    print(t"found: {found}")  # [3, 2, 6, 3, 4, 5, 20]

    var counts = List[Int]()
    for i in range(1, len(found) - 1):  # skip station ID and total
        counts.append(found[i])
    print(t"daily counts: {counts}")  # [2, 6, 3, 4, 5]

    var running_count = 0
    for c in counts:
        running_count += c
    var stated = found[len(found) - 1]
    print(t"sum: {running_count}, stated total: {stated}")
    print(t"match: {running_count == stated}")  # True

    var entry: String = "Station 3, Monday, Reading 1: 22.1 C"
    var fields = entry.split(": ")
    var tail = fields[len(fields) - 1]  # "22.1 C"
    var reading = Float64(String(tail).replace("C", "").strip())
    print(t"reading: {reading}")  # 22.1
```

## What you touched

Byte-by-byte string scanning, digit runs, `Int` and `Float64` parsing,
`raises` propagation, returning a `List` with `^`, index ranges, splitting
into fields, and validating a parse against a total the input hands you.
