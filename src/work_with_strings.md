# Work with strings 🔥

Advent input is text, and before you can compute anything you take it apart.
This page works one messy reading line every way a puzzle will ask: measure
it, slice it, search it, reshape it.

Across over a decade of puzzles, Advent of Code inputs have remained plain
ASCII. You shouldn't need to work with Unicode codepoints or grapheme
clusters. Reach for your base type: `String` and access it by ASCII bytes.

Each string is mutable, owns its data, and provides rich manipulation APIs.

## Build a string

Create `string_tour.mojo`, add this code, and run it. The spaces around
the main text are intentional:

```mojo
def main():
    var string: String = "  Day 1: 20.5C, Partly Cloudy  "
    print(t"string: '{string}'")
    # single quotes make surrounding whitespace easy to spot
```

### Checkpoint

Strings are Mojo's primary text type. They store UTF-8 encoded text and
provide a safe, ergonomic interface for string manipulation.

## String length

Use `byte_length()` to measure ASCII string length. Add:

```mojo
var length = string.byte_length()
print(t"{string} length: {length}") # 31
```

### Checkpoint

`TStrings` are templates, not strings. `print()` accepts them directly,
but you must cast them to `String` for most other uses.

Try this with and without the cast:

```mojo
# TString construction with interpolation
var t = t"5 plus 5 is {5 + 5}"
var math = "Correct: " + String(t)
print(math) # Correct: 5 plus 5 is 10
```

## String iteration

To work character-by-character, iterate over codepoint_slices(). Each
slice is a view into the original string and references a single Unicode
codepoint. With ASCII, codepoints and characters are equivalent, so each
slice behaves as a single character.

This example uses a Mojo _list comprehension_ in square brackets to return
a list of single-quoted characters. Add:

```mojo
print([slice for slice in string.codepoint_slices()])
# [ ,  , D, a, y,  , 1, :,  , 2, 0, ., 5, C, ,,  , P, a,
#  r, t, l, y,  , C, l, o, u, d, y,  ,  ]
```

### Checkpoint

- Mojo list comprehensions work just like Python, collecting loop
  results into a list.
- When working with C-like language interop, string bytes to map to `char*`.
  To extract byte data, use `unsafe_ptr()` (a pointer to the underlying
  memory), not `bytes()` (an iterator).
- Call `string.as_c_string_slice()` to return a null-terminated string.
  No change if the string is already null-terminated.

You can initialize lists directly from iterators, but this has limited
real world use:

```mojo
var list = List(string.codepoint_slices())
print(list)
# [ ,  , D, a, y,  , 1, :,  , 2, 0, ., 5, C, ,,  , P, a,
#  r, t, l, y,  , C, l, o, u, d, y,  ,  ]
```

## Join slices from lists

Use `join()` to put strings together. You call the method on a separator
string.

Add this at the end of `main()`:

```mojo
var joined = "".join([slice for slice in string.codepoint_slices()])
print(t"'{joined}')  # '  Day 1: 20.5C, Partly Cloudy  ' 
```

### Checkpoint

- `join()` supports any list of `Writable` values.
- To concatenate, use an empty separator: `"".join(parts)`.
- If you use commas, they only appear between elements:

```mojo
var hello: String = "Hello"
joined = ", ".join([slice for slice in hello.codepoint_slices()])
print(t"'{joined}'")  # 'H, e, l, l, o'
```

## Reverse a string

Reversed strings often pop up, so here are several ways to reverse your
Mojo strings.

A basic ASCII byte index reversal uses a reversed range. Add this:

```mojo
var s: String = ""

# construct and reverse the non-inclusive range
for index in reversed(range(string.byte_length())):
    s = s + String(string[byte=index])
print(t"Reversed bytes: '{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '
```

Strings provide reversed slice iterators:

```mojo
# use the reversed iterator
s = ""
for slice in string.codepoint_slices_reversed():
    s += String(slice)
print(t"'{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '
```

### Checkpoint

- The first example reverses ASCII bytes.
- `codepoint_slices_reversed()` reverses Unicode codepoints.
- List comprehensions can express either solution more concisely.

## String indexing

In Mojo, you must specify which index scheme you'll use with strings.
Calling `string[0]` is an error. Index with:

- `byte=` specifies the byte or bytes in the string data. Pass an
  integer or contiguous slice. Access is O(1).
- `codepoint=` specifies a Unicode codepoint, pass an integer or contiguous
  slice, access is O(N).
- `grapheme=` specifies a single Unicode grapheme cluster. Access is O(N).
  You can't "slice" graphemes the way you can slice bytes and codepoints.

### Using contiguous slice syntax

To access Mojo strings, you can pass a single zero-based index (an `Int` or
`IntLiteral`) or a contiguous slice:

- Use `n:m` for "n through m - 1", `[n, m)`
- Use `n:` for "the suffix starting at index n", `[n, length)`
- Use `:m` for "the prefix ending just before index m", `[0, m)`

Add these examples to your project code to see this in action:

```mojo
# O(1) byte slicing to a view
print(t"byte prefix:     '{string[byte=:5]}'")           # '  Day'
print(t"byte suffix:     '{string[byte=length - 5:]}'")  # 'udy '
print(t"byte substring:  '{string[byte=2:10]}'")         # 'Day 1: 2'
```

### Checkpoint

- With strict ASCII strings, using `byte=` and `codepoint=` indexing
  results are equivalent, but `byte=` performs better.
- Indexed content returns a view into the string's data, not a copy of the
  specified bytes.
- The flame character ("🔥") is a single grapheme. The four-member family
  ("🧑‍🧑‍🧒‍🧒") uses seven (four people, three connectors). Fun tip: iterate over
  its codepoints to see the individual family members.

## Search and check

Three patterns cover most "is this in there?" questions: the `in`
operator, `find`, and the `startswith` / `endswith` pair.

Add this at the end of `main()`:

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

- `s.find(sub)` returns the byte position of the first match, or `-1`
  if the substring isn't present. There's no "raises if missing" variant.
- `s.startswith(prefix)` and `s.endswith(suffix)` skip the `find == 0`
  bookkeeping. Useful for filtering log lines by tag.
- `s.count(sub)` returns the number of occurrences when you need it.

### Try this

Throw this into your code:

```mojo
if string.find('!'):
    print("-1 is truthy")  # This prints
else:
    print("You'd expect to be here, but you're not")
```

Don't use `find` in tests. Use `in` for containment:

```mojo
if '!' in string:
    print("Found")
else:
    print("Not found")  # This prints
```

`"x" in s` returns a `Bool`. Use it when you need yes-or-no.

After you're done, clean up the containment test.

## Strings are truthy

Check for empty strings with `if`. Add this:

```mojo
if "":
    print("Won't be printed")
elif "🔥":
    print("This is printed")
```

## Trim your strings

Remove surrounding whitespace with `strip()`. Add this to the end of main:

```mojo
var cleaned = string.strip()
print(t"cleaned: '{cleaned}', bytes: {cleaned.byte_length()}")
```

The string length drops from 31 to 27 as the white space is trimmed.

### Checkpoint

- `strip()` returns a `StringSlice` with leading and trailing whitespace
  removed. The original `string` is unchanged.
- Use `lstrip()` for the left side only and `rstrip()` for the right.

### Try this

Choose what to strip with the optional character list:

```mojo
var test = "**🔥Fooxx"
print(t"'{test.strip("x*🔥")}'")  # 'Foo'
```

The trim set matches Unicode codepoints, not bytes.

Default whitespace characters include newlines and tabs as well as spaces:

```mojo
test = "\n\n\t Hi\n \n"
print(t"'{test.strip()}'")  # 'Hi'
```

## Substituting text

`replace(old, new)` returns a new `String` with every occurrence of
`old` swapped for `new`. Pass an empty string for `new` to delete.

Add this at the end of `main()`:

```mojo
var standardized = cleaned.replace("Partly Cloudy", "Cloudy")
var no_units = standardized.replace("C", "")
print(standardized)
print(no_units)  # loudy! Maybe not a great idea
```

Run it. You should see `Day 1: 20.5C, Cloudy` and `Day 1: 20.5, loudy`.

### Checkpoint

- `replace` returns a new `String`. The original is untouched.
- The old search string doesn't have to match the replacement string length.
- It replaces every use, not just the first. That's why the `C` in `Cloudy`
  disappeared.

## Cut up your string

Use `split(sep)` to select a separator string and break a string into
pieces around it.

Add this at the end of `main()`:

```mojo
var parts = cleaned.split(", ")
print(t"split on ', ': {parts}") # [Day 1: 20.5C, Partly Cloudy]
print(t"count: {len(parts)}")  # 2
```

Run it. Two parts. `Day 1: 20.5C` and `Partly Cloudy`.

### Checkpoint

- `split(sep)` returns a `List[StringSlice]`. Each slice is a reference
  into the original string. It stays alive as long as the source does.
  And vice versa.
- For newline-aware splits (`\n`, `\r\n`, `\r`), use
  `splitlines()`. This drops any trailing final empty line caused by
  a terminal newline.
- `split()` with no argument splits on whitespace runs and drops empty
  segments. Useful when fields are separated by arbitrary spacing.

## Change case

`lower()` and `upper()` return new strings with the casing of
your choice. Useful for case-insensitive matching.

Add this at the end of `main()`:

```mojo
print(cleaned.lower())  # partly cloudy
print(cleaned.upper())  # PARTLY CLOUDY
print(t"'cloudy' matches: {'cloudy' in cleaned.lower()}")  # True
```

### Checkpoint

- `lower()` and `upper()` operate on ASCII letters only.
- Non-ASCII case folding (German `ß`, Turkish dotted-i `İ`) needs
  codepoint-by-codepoint handling with `codepoints()`.

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
    print(math) # Correct: 5 plus 5 is 10

    print("\nSTRING LENGTH")
    var length = string.byte_length()
    print(t"{string} length: {length}") # 31

    print("\nSTRING ITERATION")
    print([slice for slice in string.codepoint_slices()])
    # [ ,  , D, a, y,  , 1, :,  , 2, 0, ., 5, C, ,,  , P, a,
    #  r, t, l, y,  , C, l, o, u, d, y,  ,  ]

    print("\nITERATOR TO LIST COERSION CHECKPOINT")
    var list = List(string.codepoint_slices())
    print(list)
    # [ ,  , D, a, y,  , 1, :,  , 2, 0, ., 5, C, ,,  , P, a,
    #  r, t, l, y,  , C, l, o, u, d, y,  ,  ]

    print("\nJOINING STRING SLICES")
    var joined = "".join([slice for slice in string.codepoint_slices()])
    print(t"'{joined}'")  # '  Day 1: 20.5C, Partly Cloudy  '

    print("\nJOINING CHECKPOINT")
    var hello: String = "Hello"
    joined = ", ".join([slice for slice in hello.codepoint_slices()])
    print(t"'{joined}'")  # 'H, e, l, l, o'

    print("\nSTRING REVERSAL")
    var s: String = ""

    # construct and reverse the non-inclusive range
    for index in reversed(range(string.byte_length())):
        s = s + String(string[byte=index])
    print(t"Reversed bytes: '{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '

    # use the reversed iterator
    s = ""
    for slice in string.codepoint_slices_reversed():
        s += String(slice)
    print(t"'{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '

    print("\nSTRING INDEXING")
    print(t"byte prefix:     '{string[byte=:5]}'")           # '  Day'
    print(t"byte suffix:     '{string[byte=length - 5:]}'")  # 'udy '
    print(t"byte substring:  '{string[byte=2:10]}'")         # 'Day 1: 2'

    print("\nSEARCH AND CHECK")
    # Contains
    print(t"contains 'Day':       {'Day' in string}")  # True

    # Position
    print(t"position of ':':      {string.find(':')}")  # 7
    print(t"position of '!':      {string.find('!')}")  # -1, not found

    # Start and end
    print(t"starts with '  Day':  {string.startswith('  Day')}")   # True
    print(t"ends with 'Cloudy  ': {string.endswith('Cloudy  ')}")  # True

    print("\nTESTING SEARCHES")
    if string.find('!'):
        print("-1 is truthy")  # This prints
    else:
        print("You'd expect to be here, but you're not")

    if '!' in string:
        print("Found")
    else:
        print("Not found")   # This prints

    print("\nSTRING TRUTHYNESS")
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
    print(t"split on ', ': {parts}") # [Day 1: 20.5C, Partly Cloudy]
    print(t"count: {len(parts)}")  # 2

    print("\nCHANGING CASE")
    print(cleaned.lower())  # partly cloudy
    print(cleaned.upper())  # PARTLY CLOUDY
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
