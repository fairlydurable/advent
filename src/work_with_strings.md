# Work with strings 🔥

Advent of Code inputs arrive as text, but the answers are hiding inside:
numbers, labels, separators, commands, coordinates, and clues.

Before you can solve the puzzle, you have to take the input apart.

This page gives you one deliberately messy line and walks through the string
operations you'll reach for again and again: trim it, search it, slice it,
split it, and reshape it.

## It's plain ASCII

Advent of Code inputs are ASCII. That means one byte per character, simple
indexing, and no grapheme-cluster surprises.

For puzzle input, reach for `String` and work by byte. It's fast, direct,
and a good fit for extracting fields, checking markers, and splitting lines
into useful pieces.

## Build a string

Today's input starts with one weather report. Create `string_tour.mojo`,
add this code, and run it.

The spaces around the main text are intentional:

```mojo
def main():
    var string: String = "  Day 1: 20.5C, Partly Cloudy  "
    print(t"string: '{string}'")
    # single quotes make surrounding whitespace easy to spot
```

Each string is mutable, owns its data, and provides rich manipulation APIs.

### Checkpoint

Strings are Mojo's primary text type. They store UTF-8 encoded text and
provide a safe, ergonomic interface for string manipulation.

## Measure the input

Before you start cutting up the line, count your characters. You can use a
pre-computed length for any work that involves the end of the string, like
reversing and suffixes.

For ASCII input only, `byte_length()` gives you a string length:

```mojo
var length = string.byte_length()
```

`TStrings` (prefixed with the letter `t`) let you interpolate values
into a string template and print them:

```mojo
print(t"{string} length: {length}")  # 31
```

### Checkpoint

- `TStrings` are templates, not strings.
- `print()` accepts them directly.
- Convert a `TString` to `String` when you need to store or manipulate
  the resulting text as a string, or return a string from a function or
  method.

Try this code with and without the cast:

```mojo
# TString construction with interpolation
var t = t"5 plus 5 is {5 + 5}"
var math = "Correct: " + String(t)
print(math) # Correct: 5 plus 5 is 10
```

## String iteration

Sometimes a puzzle makes you inspect input one character at a time: looking
for markers, counting symbols, or building values as you go.

Iterate over `codepoint_slices()` to walk through the text. Each slice is a
view into the original string that references one Unicode codepoint. With
ASCII input, each codepoint is one character.

This example uses a Mojo list comprehension to collect the individual
characters and convert each slice to a single-quoted string:

```mojo
print([String(t"'{slice}'") for slice in string.codepoint_slices()])
# [' ', ' ', 'D', 'a', 'y', ' ', '1', ':', ' ', '2', '0', '.', '5',
#  'C', ',', ' ', 'P', 'a', 'r', 't', 'l', 'y', ' ', 'C', 'l', 'o',
#  'u', 'd', 'y', ' ', ' ']
```

### Checkpoint

- String iteration walks your input character-by-character. This lets you
  locate markers and symbols in your puzzles, plus build values.
- This example happens to use a Mojo list comprehension. They work just
  like Python, collecting loop results into lists.
- When working with C-like language interop, string bytes map to `char*`.
  To extract byte data, use `unsafe_ptr()` (a pointer to the underlying
  memory), not `bytes()` (an iterator).
- Call `string.as_c_string_slice()` to return a null-terminated string.
  No change if the string is already null-terminated.

## Join slices from lists

Taking input apart is only half the job. Sometimes you keep the pieces you
want and need to put them back together.

Use `join()` to combine values into a string. Call the method on the
separator you want to place between them.

To rebuild the original line, use an empty separator:

```mojo
var joined = "".join([slice for slice in string.codepoint_slices()])
print(t"'{joined}'")  # '  Day 1: 20.5C, Partly Cloudy  '
```

To rebuild the original line without spaces, filter them out:

```mojo
joined = "".join([
    slice for slice in string.codepoint_slices()
    if " " not in slice])
print(t"'{joined}'")  #  'Day1:20.5C,PartlyCloudy'
```

### Checkpoint

- `join()` supports any list of `Writable` values.
- Use an empty separator to concatenate values: `"".join(parts)`.
- A non-empty separator appears only between elements.

For example:

```mojo
var hello: String = "Hello"
joined = ", ".join([slice for slice in hello.codepoint_slices()])
print(t"'{joined}'")  # 'H, e, l, l, o'
```

## Reverse a string

Puzzles love making you read things backward: mirrored patterns, reversed
paths, and sequences that need to match in either direction.

For ASCII input, you can reverse the bytes by walking backward from the end
of the string:

```mojo
var s: String = ""

# construct and reverse the non-inclusive range
for index in reversed(range(length)):
    s = s + String(string[byte=index])
print(t"Reversed bytes: '{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '
```

Strings also provide a reversed slice iterator:

```mojo
# use the reversed iterator
s = ""
for slice in string.codepoint_slices_reversed():
    s += String(slice)
print(t"'{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '
```

### Checkpoint

- For ASCII sources, reversing bytes and reversing codepoints produces the
  same result.
- `reversed(range(length))` walks the byte indices from the end to the
  beginning.
- `codepoint_slices_reversed()` gives you an iterator that walks Unicode
  codepoints in reverse without calling `reversed()`.

## Slice out what you need

Puzzle inputs often pack several pieces of information into one line. When
you know where the data you want appears, indexing and slicing let you
reach directly into the text.

Mojo strings support three indexing schemes. You must state the one you're
using. Calling `string[0]` is an error:

- `byte=` indexes the underlying bytes. Pass an integer or contiguous slice.
  Access is O(1).
- `codepoint=` indexes Unicode codepoints. Pass an integer or contiguous
  slice. Access is O(N).
- `grapheme=` indexes a single Unicode grapheme cluster. Access is O(N).
  Grapheme indexing doesn't support slices.

For ASCII puzzle input, use `byte=`.

### Slice the line

Slices let you grab a prefix, suffix, or section from the middle:

- `n:m` selects from `n` through `m - 1`: `[n, m)`.
- `n:` selects the suffix starting at `n`: `[n, length)`.
- `:m` selects the prefix ending before `m`: `[0, m)`.

Try all three on the puzzle input:

```mojo
# O(1) byte slicing to a view
print(t"byte prefix:     '{string[byte=:5]}'")           # '  Day'
print(t"byte suffix:     '{string[byte=length - 5:]}'")  # 'udy  '
print(t"byte substring:  '{string[byte=2:10]}'")         # 'Day 1: 2'
```

### Checkpoint

- For ASCII input, `byte=` and `codepoint=` give you the same results,
  but byte indexing is faster.
- Indexed content returns a view into the string's data, not a copy.

## Search for clues

Before you parse a line, you often need to know what it contains. Does it
have the marker you need? Where does a field start? Does the line have the
right prefix or suffix?

Three tools cover these common searches: `in`, `find()`, and
`startswith()` / `endswith()`.

Try them on your input:

```mojo
# Contains
print(t"contains 'Day':       {'Day' in string}")  # True

# Position
print(t"position of ':':      {string.find(':')}")  # 7
print(t"position of '!':      {string.find('!')}")  # -1, not found

# Start and end
print(t"starts with '  Day':  {string.startswith('  Day')}")   # True
print(t"ends with 'Cloudy  ': {string.endswith('Cloudy  ')}")  # True
```

Run it. You should see `True`, `7`, `-1`, `True`, `True`.

### Checkpoint

- Use `sub in s` when you need a yes-or-no containment check.
- `s.find(sub)` returns the byte position of the first match, or `-1` when
  the substring isn't present.
- `s.startswith(prefix)` and `s.endswith(suffix)` test the ends directly.
  They're useful for filtering input lines by markers or tags.
- `s.count(sub)` counts occurrences when you need more than presence.

### Try this

There's a trap hiding in `find()`. A missing value returns `-1`, and `-1`
is truthy:

```mojo
if string.find('!'):
    print("-1 is truthy")  # This prints
else:
    print("You'd expect to be here, but you're not")
```

That's why you shouldn't use `find()` as a containment test. Use `in`:

```mojo
if '!' in string:
    print("Found")
else:
    print("Not found")  # This prints
```

`"x" in s` returns a `Bool`. Reach for `find()` when you need the
position. Reach for `in` when you only need to know whether it's there.

## Test for empty strings

You just saw that integers have truthiness. Strings do too. An empty string
is falsy and a non-empty string is truthy:

```mojo
if "":
    print("Won't be printed")
elif "🔥":
    print("This is printed")
```

### Checkpoint

Use string truthiness when you care whether text is empty:

```mojo
if text:
    # There's something to process.
```

Use `in` when you care whether specific text appears.

## Clean up the edges

Puzzle input often comes with whitespace you don't want: spaces around
fields, indentation, or trailing newlines. Use `strip()` to remove
whitespace from both ends.

Clean up your reading line:

```mojo
var cleaned = string.strip()
print(t"cleaned: '{cleaned}', bytes: {cleaned.byte_length()}")
```

The string length drops from 31 to 27 as the white space is trimmed.

### Checkpoint

- `strip()` returns a `StringSlice` without leading and trailing whitespace.
- Use `lstrip()` to clean the left edge only, and `rstrip()` for the right.

### Try this

You can tell `strip()` exactly which characters to remove:

```mojo
var test = "**🔥Fooxx"
print(t"'{test.strip("x*🔥")}'")  # 'Foo'
```
The trim set matches Unicode codepoints, not bytes.

Without an argument, strip() removes whitespace, including newlines and
tabs:

```mojo
test = "\n\n\t Hi\n \n"
print(t"'{test.strip()}'")  # 'Hi'
```

## Replace what you know

Sometimes puzzle input contains text you want to normalize before you
process it. Use `replace(old, new)` to replace every occurrence of one
substring with another.

Standardize the weather description:

```mojo
var standardized = cleaned.replace("Partly Cloudy", "Cloudy")
var no_units = standardized.replace("C", "")
print(standardized)
print(no_units)  # loudy! Maybe not a great idea
```

Run it. You should see `Day 1: 20.5C, Cloudy` and `Day 1: 20.5, loudy`.

Oops. You removed the C from Cloudy, too.

### Checkpoint

- `replace()` returns a new `String`. The original is unchanged.
- The replacement can have a different length from the text it replaces.
- `replace()` replaces _every_ match, not just the one you had in mind.

## Cut up your string

## Split the line into fields

Your cleaned line still contains two different pieces of information: the
reading and the weather description. When input has a consistent separator,
use `split(sep)` to break it into fields.

Split on the comma and space:

```mojo
var parts = cleaned.split(", ")
print(t"split on ', ': {parts}") # [Day 1: 20.5C, Partly Cloudy]
print(t"count: {len(parts)}")  # 2
```

Now you can work with "Day 1: 20.5C" and "Partly Cloudy" separately.

### Checkpoint

- `split(sep)` returns a `List[StringSlice]`. Each slice is a view into
  the original string, not a copy.
- `split()` with no argument splits on runs of whitespace and drops empty
  segments. Reach for it when fields are separated by inconsistent spacing.

## Normalize for matching

Sometimes you care about the text but not its capitalization. Normalize
the case before you compare or search.

You already split the weather description into `parts[1]`. Try both
directions:

```mojo
print(parts[1].lower())  # partly cloudy
print(parts[1].upper())  # PARTLY CLOUDY
```

Now you can make a case-insensitive containment check by normalizing before
you search:

```mojo
print(t"'cloudy' matches: {'cloudy' in cleaned.lower()}")  # True
```

### Checkpoint

- `lower()` and `upper()` return new strings. They don't change the original.
- They operate on ASCII letters only.
- For Advent's ASCII input, normalizing case gives you a simple way to
  compare text without worrying about capitalization.

## Final code

Your complete `string_tour.mojo`, including checkpoint and other material.

```mojo
def main():
    print("STRING ASSIGNMENT")
    var string: String = "  Day 1: 20.5C, Partly Cloudy  "
    print(t"string: '{string}'")

    print("\nTSTRING CHECKPOINT")
    # TString construction with interpolation
    var t = t"5 plus 5 is {5 + 5}"
    var math = "Correct: " + String(t)
    print(math)  # Correct: 5 plus 5 is 10

    print("\nSTRING LENGTH")
    var length = string.byte_length()
    print(t"{string} length: {length}")  # 31

    print("\nSTRING ITERATION")
    print([String(t"'{slice}'") for slice in string.codepoint_slices()])
    # [' ', ' ', 'D', 'a', 'y', ' ', '1', ':', ' ', '2', '0', '.', '5',
    #  'C', ',', ' ', 'P', 'a', 'r', 't', 'l', 'y', ' ', 'C', 'l', 'o',
    #  'u', 'd', 'y', ' ', ' ']

    print("\nJOINING STRING SLICES")
    var joined = "".join([slice for slice in string.codepoint_slices()])
    print(t"'{joined}'")  #  '  Day 1: 20.5C, Partly Cloudy  '

    joined = "".join([
        slice for slice in string.codepoint_slices()
        if " " not in slice])
    print(t"'{joined}'")  #  'Day1:20.5C,PartlyCloudy'

    print("\nJOINING CHECKPOINT")
    var hello: String = "Hello"
    joined = ", ".join([slice for slice in hello.codepoint_slices()])
    print(t"'{joined}'")  # 'H, e, l, l, o'

    print("\nSTRING REVERSAL")
    var s: String = ""

    # construct and reverse the non-inclusive range
    for index in reversed(range(length)):
        s = s + String(string[byte=index])
    print(t"Reversed bytes: '{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '

    # use the reversed iterator
    s = ""
    for slice in string.codepoint_slices_reversed():
        s += String(slice)
    print(t"'{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '

    print("\nSTRING INDEXING")
    print(t"byte prefix:     '{string[byte=:5]}'")  # '  Day'
    print(t"byte suffix:     '{string[byte=length - 5:]}'")  # 'udy '
    print(t"byte substring:  '{string[byte=2:10]}'")  # 'Day 1: 2'

    print("\nSEARCH AND CHECK")
    # Contains
    print(t"contains 'Day':       {'Day' in string}")  # True

    # Position
    print(t"position of ':':      {string.find(':')}")  # 7
    print(t"position of '!':      {string.find('!')}")  # -1, not found

    # Start and end
    print(t"starts with '  Day':  {string.startswith('  Day')}")  # True
    print(t"ends with 'Cloudy  ': {string.endswith('Cloudy  ')}")  # True

    print("\nTESTING SEARCHES")
    if string.find("!"):
        print("-1 is truthy")  # This prints
    else:
        print("You'd expect to be here, but you're not")

    if "!" in string:
        print("Found")
    else:
        print("Not found")  # This prints

    print("\nSTRING TRUTHINESS")
    if "":
        print("Won't be printed")
    elif "🔥":
        print("This is printed")

    print("\nTRIMMING STRINGS")
    var cleaned = string.strip()
    print(t"cleaned: '{cleaned}', bytes: {cleaned.byte_length()}")

    print("\nTRIMMING TRY THIS")
    var test = "**🔥Fooxx"
    print(t"'{test.strip("x*🔥")}'")  # 'Foo'

    test = "\n\n\t Hi\n \n"
    print(t"'{test.strip()}'")  # 'Hi'

    print("\nSUBSTITUTIONS")
    var standardized = cleaned.replace("Partly Cloudy", "Cloudy")
    var no_units = standardized.replace("C", "")
    print(standardized)
    print(no_units)  # loudy! Maybe not a great idea

    print("\nSPLITTING STRINGS")
    var parts = cleaned.split(", ")
    print(t"split on ', ': {parts}")  # [Day 1: 20.5C, Partly Cloudy]
    print(t"count: {len(parts)}")  # 2

    print("\nCHANGING CASE")
    print(parts[1].lower())  # partly cloudy
    print(parts[1].upper())  # PARTLY CLOUDY
    print(t"'cloudy' matches: {'cloudy' in cleaned.lower()}")  # True
```

## What you touched

String lengths, bytes vs codepoints, indexing, slicing, content operators,
trimming, replacement, splits, casing, and join.

## Also worth knowing

**Prefixes and suffixes**:

`removeprefix(prefix)` and `removesuffix(suffix)` are the surgical
versions of `replace`. They strip the substring only if it appears at
the relevant end. Safer than `replace` when the same substring might
appear elsewhere in the string.

**Iterating over characters**:

`for ch in s.codepoints():` walks each Unicode codepoint as a
`Codepoint`. `for slice in s.codepoint_slices():` gives you each
codepoint as a `StringSlice` you can compare to a literal. Cast
the slices to `String` to use them with string construction.

**Counting**:

`s.count(sub)` returns how many non-overlapping copies of `sub` appear
in `s`. Pair it with `find` and `replace` for full
search-and-substitute work.
