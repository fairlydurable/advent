# Reuse your code 🔥

Your puzzle is really the same handful of moves every day: read the input,
pull the numbers, clean them up. Here's what you need: wrap those moves in
functions you write once and call all December.

## The moves you keep repeating

By now you've pulled integers from text, corrected readings, and averaged
them. You wrote each move inline. A function gives the move a name and a
home, letting the next puzzle reuse it instead of retyping it.

### Build a library

Create a folder called `toolkit/`.

In that folder, create `__init__.mojo` and add extractor. There's no
`main()` function, just the one `extract_ints()` function:

```mojo
def extract_ints(text: String) raises -> List[Int]:
    var nums = List[Int]()
    var cur = String("")
    for i in range(text.byte_length()):
        var c = String(text[byte=i])
        if c >= "0" and c <= "9":
            cur += c
        elif cur:
            nums.append(Int(cur))
            cur = String("")
    if cur:
        nums.append(Int(cur))
    return nums^
```

Compile it with `precompile`. This builds toolkit.mojoc:

```bash
mojo precompile toolkit.mojo
```

### Link a library

Now create `test.mojo` in your main folder, not inside `toolkit`:

```bash
from toolkit import extract_ints

def main():
    var s = "a 1 b 2 c 3"
    try:
        var list = extract_ints(s)
        print(list)
    except e:
        print(e)
```

Compile and run test.mojo:

```bash
mojo test.mojo toolkit.mojoc
```

Your app prints `[1, 2, 3]` using the function from your library.

### Checkpoint

- A library lets you write once and use often.
- The declarations in the library are your API contract. `extract_ints`
  promises a `List[Int]` and hands ownership out with `^`.
- The same tool now works on input you've never seen.

## Default arguments

A parameter can carry a default, so callers skip it in the common case and
override it when they need to. Station 3 reads high when the sun hits it
midday, so correct readings taken in those hours. Add to your library:

```mojo
def corrected(reading: Float64, hour: Int, offset: Float64 = 1.5) -> Float64:
    # station 3 bakes in solar loading between 10:00 and 14:00
    if 10 <= hour < 14:
        return reading - offset
    return reading
```

Call it from `main()` with the default, or name the argument to override it:

```mojo
print(t"noon, default: {corrected(24.5, 12)}")              # 23.0
print(t"noon, bigger:  {corrected(24.5, 12, offset=2.0)}")  # 22.5
```

### Checkpoint

- `offset: Float64 = 1.5` gives the parameter a default. Callers that omit
  supplying their own `offset` use this as their offset value.
- Name an argument at the call site (`offset=2.0`) to set it explicitly and
  skip the guesswork about argument order.
- A default keeps the common call short.

## Compose functions

Small functions snap together. Add one that averages a list, then run readings
through correction and into the average. In the library:

```mojo
def mean_of(values: List[Float64]) -> Float64:
    var total = 0.0
    for v in values:
        total += v
    return total / Float64(len(values))
```

In `main()`, correct each reading, then summarize the corrected set:

```mojo
    var raw: List[Float64] = [22.1, 24.5, 19.8]
    var hours = [9, 12, 16]
    var fixed = List[Float64]()
    for r, h in zip(raw, hours):
        fixed.append(corrected(r, h))
    print(t"corrected: {fixed}")  # [22.1, 23.0, 19.8]
    print(t"mean after correction: {round(mean_of(fixed), 2)}")  # 21.63
```

### Checkpoint

- Each function does one thing, so they read as a pipeline: parse, correct,
  summarize.
- `corrected` runs per reading; `mean_of` runs over the whole list. Small
  pieces, combined at the call site.

## Final code

Your complete `toolkit/__init__.mojo`:

```mojo
def extract_ints(text: String) raises -> List[Int]:
    var nums = List[Int]()
    var cur = String("")
    for i in range(text.byte_length()):
        var c = String(text[byte=i])
        if c >= "0" and c <= "9":
            cur += c
        elif cur:
            nums.append(Int(cur))
            cur = String("")
    if cur:
        nums.append(Int(cur))
    return nums^


def corrected(reading: Float64, hour: Int, offset: Float64 = 1.5) -> Float64:
    # station 3 bakes in solar loading between 10:00 and 14:00
    if 10 <= hour < 14:
        return reading - offset
    return reading


def mean_of(values: List[Float64]) -> Float64:
    var total = 0.0
    for v in values:
        total += v
    return total / Float64(len(values))
```

and:

```mojo
from toolkit import extract_ints, corrected, mean_of

def main() raises:
    print(t"reused: {extract_ints('readings: 3, 5, 8')}")  # [3, 5, 8]

    print(t"noon, default: {corrected(24.5, 12)}")              # 23.0
    print(t"noon, bigger:  {corrected(24.5, 12, offset=2.0)}")  # 22.5

    var raw: List[Float64] = [22.1, 24.5, 19.8]
    var hours = [9, 12, 16]
    var fixed = List[Float64]()
    for r, h in zip(raw, hours):
        fixed.append(corrected(r, h))
    print(t"corrected: {fixed}")                       # [22.1, 23.0, 19.8]
    print(t"mean after correction: {round(mean_of(fixed), 2)}")  # 21.63
```

## What you touched

Building a library and linking it, naming a move as a function, return-type
contracts, returning a `List` with `^`, default arguments, keyword
arguments at the call site, and composing small functions into a pipeline.
