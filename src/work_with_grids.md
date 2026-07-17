# Work with grids 🔥

Dr. Green has been wondering if some warming devices aren't working
in the garden. The crops aren't happy in some places. Solution: a grid
of temperature sensors across the garden.

You'll find nearest neighbor searches in Advent of Code problems. Your
puzzle provides grid data. You determine where your grid has cool spots.

Here's what you need: store a grid, index it, walk its neighbors, and
apply some math.

## Today's data

Some puzzles hand you a text file, where you can break down a string from
line-by-line text. Others provide input, where you end up with a list. Your
garden puzzle went with the second option for a 3 row, 4 column grid:

```text
8, 7, 8, 9, 7, 5, 6, 8, 8, 6, 7, 9
```

To model this as a grid, create `grid.mojo` and add a new type:

```mojo
struct Grid:
    var data: List[Int]  # backing data
    var cols: Int  # the number of columns
    var rows: Int  # the number of rows

    def __init__(out self, var data: List[Int], cols: Int):
        self.data = data^  # Transfer data
        self.cols = cols   # Copy data
        self.rows = len(self.data) / cols  # Calculate data
```

### Checkpoint

- Your new type has three fields: a list and two integers.
- Every field must be initialized in your initializer.
- You don't have to _pass_ every field value to the initializer. `row` is
  calculated for you in this implementation.
- There's no integrity check here so pass data that is `row * cols` big.
- All instance methods in struct types use `self` as their first argument.
  In initializers, `out` lets you return the newly constructed value without
  a return arrow.

## Construct your grid

Put your test values into a `List` and build a grid from that data:

Add `main()`:

```mojo
def main():
    # Uses row-major input
    var input = [8, 7, 8, 9, 7, 5, 6, 8, 8, 6, 7, 9]
    var cols = 4
    var grid = Grid(input^, cols)
```

### Checkpoint

- When constructing the `Grid`, you transfer ownership of `input` with `^`.
  Using `var` before `data` in the initializer tells the grid to expect that
  transfer.
- Don't try to print `input` after assigning `grid`. It no longer has a value.
- Your data is available in `grid.data` but there's currently no special
  row/column indexing.

## Add index conversion

Your data is just a list. It doesn't become a grid until you provide a way
to access it with (row, column) coordinates. These two utility methods let
you move in both directions. Add them to your `Grid` type:

```mojo
# Convert index from row/col to linear
def index(self, row: Int, col: Int) -> Int:
    return row * self.cols + col

# Convert index from linear to row/col
def index(self, at: Int) -> Tuple[Int, Int]:
    return (at / self.cols, at % self.cols)
```

Test this out with an index of `(1, 3)`. It should return 7. Your grid
uses row-major indices.

## Add direct grid indexes

Mojo's `__getdata__()` dunder methods unlock square brackets lookup.

Add the following methods to your `Grid` struct, so you can call `grid[7]`
and `grid[row=1, col=3]` to fetch values:

```mojo
# Return the value at `index`
def __getitem__(self, index: Int) -> Int:
    return self.data[index]

# Return the value at (row, col)
def __getitem__(self, *, row: Int, col: Int) -> Int:
    return self.data[self.index(row, col)]

# Return the entire row at `row` as a list
def __getitem__(self, *, row: Int) -> List[Int]:
    var start = self.index(row, 0)
    var end = self.index(row + 1, 0)
    return List[Int](self.data[start:end]) # convert the Span to a List
```

### Checkpoint

- You can overload `__getitem__()` for as many square-bracket schemes as
  you need.
- Placing an asterisk in a declaration makes the following argument
  require keywords. That's why you index with `row=` and `col=`.

## Print your grid

As you work on your puzzles, you'll want to see grids using 2-D layouts.
Build some feedback into your grid by making it `Writable`. Add the
`Writable` trait to your type:

```mojo
struct Grid(Writable):
```

Then, build a `write_to()` method to satisfy your trait conformance
requirement:

```mojo
# Required by `Writable`
def write_to(self, mut writer: Some[Writer]):
    var rows: Int = len(self.data) / self.cols
    var print_width = 4
    for row in range(rows):  # Walk each row
        for item in self[row=row]:
            writer.write(t"{String(item).ascii_rjust(print_width)}")
        if row < rows - 1:
            writer.write("\n")
```

Now you can print your grid in `main()` with `print(grid)`:

```text
   8   7   8   9
   7   5   6   8
   8   6   7   9
```

### Checkpoint

- Adjust your `print_width` as desired.
- Call `ascii_rjust()` to use pad your string with right justification.
  This defaults to using spaces for the padding. Mojo's standard library
  also offers `ascii_ljust()` and `ascii_center()`.
- This code uses the row-at-a-time fetcher you just built.

## Checking neighbors

Most grid puzzles compare a cell to its neighbors. To see if a coordinate
is a "cool spot", find out how many neighbors are warmer, and how many
are colder.

Add this code to set up your puzzle specifics, namely a neighbor radius of
one away from each spot:

```mojo
var cool_spots = 0  # cumultive count of cooler spots
var radius = 1      # How wide to search neighbors
var count = (radius * 2 + 1) ** 2 - 1  # number of neighbors to compare against
var half_count = count / 2  # half of the neighbors
```

Add this to the end of `main()` and run it. Your sample garden only has two
interior spots, and they are both cool spots. Bad news for Dr. Green:

```mojo
for index in range(len(grid.data)):
    var row, col = grid.index(index)   # fetch the row and column
    var cooler = 0             # keeps a running comparison count
    var spot = grid[row=row, col=col]  # the current spot's value

    # Check boundary safety
    if not (radius <= row < grid.rows - radius and 
            radius <= col < grid.cols - radius):
        continue

    for dRow in range(-radius, radius + 1):
        for dCol in range(-radius, radius + 1):
            if dRow == 0 and dCol == 0: continue  # skip the current spot
            var neighbor = grid[row=(row + dRow), col=(col + dCol)]
            if neighbor > spot:
                cooler += 1
    if cooler > half_count:  # each spot has 8 neighbors
        print(t"({row}, {col}) is cooler")
        cool_spots += 1

print(t"Cool spots: {cool_spots}")
```

This code iterates through each available spot, looks at its neighbors
and compares its temperatures. If there are 5 or more neighbors out of
8 that are hotter, it is a cool spot.

Try swapping out the first of the two 6s to 10, and run again. Your
cool spot count drops to one. You can also add more rows and columns
to extend your checks.

### Checkpoint

- The boundary check uses chained comparisons, ensuring each spot has
  enough space around it to allow indexing out from it.
- In Mojo, chained comparisons are pairwise. `a < b <= c` is equivalent to
  `a < b and b <= c`.
- The two delta lists (`dRow` and `dCol`) iterate across offsets from
  the current spot.
- This code skips the case (0, 0), where you compare a spot to itself.
- The neighbor look-up uses `[row=, col=]` indexing adjusted by deltas in
  each direction.
- `cooler` provides a running tally of neighbor comparisons.
- `cool_spots` provides a running tally of cool spots.

## Final code

Your complete `grid.mojo`:

```mojo
struct Grid(Writable):
    var data: List[Int]
    var cols: Int
    var rows: Int

    def __init__(out self, var data: List[Int], cols: Int):
        self.data = data^
        self.cols = cols
        self.rows = len(self.data) / cols

    # Convert index from row/col to linear
    def index(self, row: Int, col: Int) -> Int:
        return row * self.cols + col

    # Convert index from linear to row/col
    def index(self, at: Int) -> Tuple[Int, Int]:
        return (at / self.cols, at % self.cols)

    # Return the value at `index`
    def __getitem__(self, index: Int) -> Int:
        return self.data[index]

    # Return the value at (row, col)
    def __getitem__(self, *, row: Int, col: Int) -> Int:
        return self.data[self.index(row, col)]

    # Return the entire row at `row` as a list
    def __getitem__(self, *, row: Int) -> List[Int]:
        var start = self.index(row, 0)
        var end = self.index(row + 1, 0)
        return List[Int](self.data[start:end])  # convert the Span to a List

    # Required by `Writable`
    def write_to(self, mut writer: Some[Writer]):
        var rows: Int = len(self.data) / self.cols
        var print_width = 4
        for row in range(rows):
            for item in self[row=row]:
                writer.write(t"{String(item).ascii_rjust(print_width)}")
            if row < rows - 1:
                writer.write("\n")


def main():
    # Uses row-major input
    var input = [8, 7, 8, 9, 7, 5, 6, 8, 8, 6, 7, 9]
    var cols = 4
    var grid = Grid(input^, cols)
    # print(grid.index(1, 3))    # 7
    # print(grid[7])             # 8
    # print(grid[row=1, col=3])  # 8
    print(grid)

    var cool_spots = 0  # cumultive count of cooler spots
    var radius = 1  # How wide to search neighbors
    var count = (
        radius * 2 + 1
    ) ** 2 - 1  # number of neighbors to compare against
    var half_count = count / 2  # half of the neighbors

    for index in range(len(grid.data)):
        var row, col = grid.index(index)  # fetch the row and column
        var cooler = 0  # keeps a running comparison count
        var spot = grid[row=row, col=col]  # the current spot's value

        # Check boundaries
        if not (
            radius <= row < grid.rows - radius
            and radius <= col < grid.cols - radius
        ):
            continue

        for dRow in range(-radius, radius + 1):
            for dCol in range(-radius, radius + 1):
                if dRow == 0 and dCol == 0:
                    continue  # skip the current spot
                var neighbor = grid[row=(row + dRow), col=(col + dCol)]
                if neighbor > spot:
                    cooler += 1
        if cooler > half_count:  # each spot has 8 neighbors
            print(t"({row}, {col}) is cooler")
            cool_spots += 1

    print(t"Cool spots: {cool_spots}")
```

## What you touched

Nested lists as a grid, row-major indexing, nested loops to walk every
cell, coordinate deltas held in a list, tuple unpacking, chained
comparisons for bounds checks, and the walk-and-check-neighbors pattern.
