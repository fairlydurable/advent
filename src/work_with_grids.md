# Work with grids 🔥

Dr. Green grows fresh vegetables for the entire North Pole in a cozy
greenhouse tucked behind the workshop. Unfortunately, a few warming pads
have quietly failed, and the lettuce has started filing formal complaints.
It's time to find the cold spots before dinner becomes very crunchy and the
iceberg lettuce lives up to its name.

Fortunately, every square in the garden has a temperature sensor.

Your puzzle gives you the temperature readings as a grid. Your job is to
find the cool spots by comparing each sensor with its neighbors.

Along the way you'll learn how to represent a grid, convert between
coordinates and array indices, walk neighboring cells, and visualize
your results.

## Today's data

Until now, you've mostly worked with strings and lists. Many Advent
puzzles instead describe a two-dimensional world: a map, maze, image,
game board, or sensor grid.

Although the data is conceptually two-dimensional, it's usually easiest to
store it as a single list. You recover rows and columns with a little
arithmetic.

### The data

Here's today's puzzle data:

<!-- markdownlint-disable MD013 -->

```text
 6,  13,   6,   9,   8,  14,   3,
 9,  10,  11,  14,  11,  10,   8,
 9,   9,   6,   6,   8,  14,   6,
12,  11,   3,   4,   7,   7,   4,
14,   7,   8,   6,   5,   8,   6
```

<!-- markdownlint-enable MD013 -->

### Create the project file

Add this to `grid.mojo`:

``` mojo
def main():
    var data = [ ... ] # from above
    var rows, cols = 5, 7
```

The list contains five rows of seven readings each.

## Convert between indices and coordinates

The readings live in a single list, but puzzles think in rows and
columns. You'll constantly move between the two representations.

Add these helper functions in `main()` as nested items:

``` mojo
def index_to_coord(index: Int) {imm} -> Tuple[Int, Int]:
    return (index / cols, index % cols)

def get_coord_data(row: Int, col: Int) {imm} -> Int:
    return data[row * cols + col]
```

The first converts a list index into (row, col). The second converts a
row and column back into a list index to retrieve the value.

### Checkpoint

- `{imm}` gives the nested functions read-only access to values defined in
  `main()`. Here it captures `rows`, `cols`, and `data` as immutable
  references.
- The data stays in one linear list using row-major ordering.
- Division finds the row. Modulo finds the column.
- Looking up a coordinate computes an index instead of copying data.
- Returning coordinates as a tuple lets you unpack them naturally.

## Print the grid

Before solving the puzzle, it's helpful to see the data laid out as a
grid.

Add a `write_data()` helper that loops over each row and column, formats
the values into aligned columns with `ascii_rjust()`, and prints the
result.

Run it to verify the input before you start searching.

```mojo
# Write the data in a grid format
def write_data() {imm data, imm}:
    var print_width = 4
    for row in range(rows):
        for idx in range(row * cols, (row + 1) * cols):
            var item = data[idx]
            print(t"{String(item).ascii_rjust(print_width)}", end="")
        if row < rows - 1:
            print("")
    print()

write_data()
```

### Checkpoint

- `ascii_rjust()` right-aligns values into fixed-width columns.
- Adjust `print_width` if your values become wider.
- Nested loops naturally walk rows and columns.

## Compare neighboring cells

A single reading doesn't tell you much. Is 6 cold? Compared to what?
Is that a cool spot? How do you know? Do you pick a cut-off number?

The interesting part is how each reading compares with the temperatures
around it. For this puzzle, a point is considered a **cool spot** if most
of its neighbors are warmer.

### Clarifying the search

You'll need to define some puzzle parameters to limit your search and
produce your results.

``` mojo
var radius = 1      # how far to look
var count = (radius * 2 + 1) ** 2 - 1  # how many neighbors?
var half_count = count / 2             # half of the neighbors
```

A radius of one creates a 3×3 neighborhood. Excluding the center leaves
eight neighboring cells.

### Performing the search

Here's the heart of your project. For each location, you examine the
square neighborhood centered on that spot. Every warmer neighbor
increments `cooler`. If more than half the neighbors are warmer, you've
found a cool spot.

```mojo
for index in range(len(data)):
    var row, col = index_to_coord(index)         # fetch the row and column
    var cooler = 0                       # keeps a running comparison count
    var spot = get_coord_data(row=row, col=col)  # the current spot's value

    # Check boundaries for safe indexing
    if not (radius <= row < rows - radius
        and radius <= col < cols - radius):
        continue

    for dRow in range(row - radius, row + radius + 1):
        for dCol in range(col - radius, col + radius + 1):
            if dRow == row and dCol == col: continue  # current spot
            var neighbor = get_coord_data(row=dRow, col=dCol)
            if neighbor > spot: cooler += 1

    if cooler > half_count:  # each spot has 8 neighbors
        print(t"Cool spot: ({row}, {col})")
```

The boundary check uses chained comparisons to make sure that at the
current spot, there are at least radius values in each direction. This
makes sure indexes in the following loop are safe.

Chained comparisons split pairwise: `x < y <= z` is equivalent to
`x < y and y <= z`. They're a compact Mojo way to express related
checks.

When you run the search, you'll find four cool spots. In the next step,
you'll mark them on the grid so they're easy to see.

### Checkpoint

- The outer loop visits every cell.
- The inner loops visit each neighboring location.
- The current cell is skipped.
- `cooler` counts warmer neighbors for one location.

## Visualize the answer

Finding the answer is good.

Seeing it is even better.

Follow these four steps to update `write_data()` to mark cool spots with
`*`, then call it again after the search finishes.

1. Add this before your `write_data()` method:

   ```mojo
   var cool_indices: List[Tuple[Int, Int]] = []
   ```

2. Append the `(row, col)` tuple to the `cool_indices` list:

   ```mojo
   if cooler > half_count:  # each spot has 8 neighbors
       print(t"Cool spot: ({row}, {col})")
       cool_indices.append((row, col))  # add this
   ```

3. At the very end of `main()` call `write_data()`:

   ```mojo
   write_data()
   ```

4. Update `write_data()` with this code, so it will use the `cool_indices`
   list to mark your results:

   ```mojo
   def write_data() {imm data, imm}:
       var print_width = 4
       for row in range(rows):
           for idx in range(row * cols, (row + 1) * cols):
               var item = data[idx]
               var col = idx % cols
               print(t"{String(item).ascii_rjust(print_width)}", end="")
               if (row, col) in cool_indices:
                   print(t"*", end="")
               else:
                   print(t" ", end="")
           if row < rows - 1:
               print("")
       print()
   ```

### Checkpoint

- Store interesting coordinates separately instead of modifying the
  data.
- The same display routine works before and after the search.
- Simple visualization is an effective debugging tool.

## Run the app

The highlighted grid makes it clear where the colder regions are:

```text
   6   13    6    9    8   14    3 
   9   10   11   14   11   10    8 
   9    9    6*   6*   8   14    6 
  12   11    3*   4*   7    7    4 
  14    7    8    6    5    8    6 
```

The failed warming pad is immediately obvious.

## Final code

Your complete `grid.mojo`:

<!-- markdownlint-disable MD013 -->

```mojo
def main():

    var data = [
          6,  13,   6,   9,   8,  14,   3,
          9,  10,  11,  14,  11,  10,   8,
          9,   9,   6,   6,   8,  14,   6,
         12,  11,   3,   4,   7,   7,   4,
         14,   7,   8,   6,   5,   8,   6
    ]

    var rows, cols = 5, 7

    # Convert index from linear to row/col
    def index_to_coord(index: Int) {imm} -> Tuple[Int, Int]:
        return (index / cols, index % cols)

    # Convert index from row/col to linear
    def get_coord_data(row: Int, col: Int) {imm} -> Int:
        return data[row * cols + col]

    var cool_indices: List[Tuple[Int, Int]] = []

    # Write the data in a grid format
    def write_data() {imm data, imm}:
        var print_width = 4
        for row in range(rows):
            for idx in range(row * cols, (row + 1) * cols):
                var item = data[idx]
                var col = idx % cols
                print(t"{String(item).ascii_rjust(print_width)}", end="")
                if (row, col) in cool_indices:
                    print(t"*", end="")
                else:
                    print(t" ", end="")
            if row < rows - 1:
                print("")
        print()

    write_data()

    var radius = 1  # How wide to search neighbors
    var count = (radius * 2 + 1) ** 2 - 1  # neighbor count (3x3 - 1)
    var half_count = count / 2  # half of the neighbors (4)

    for index in range(len(data)):
        var row, col = index_to_coord(index)         # fetch the row and column
        var cooler = 0                       # keeps a running comparison count
        var spot = get_coord_data(row=row, col=col)  # the current spot's value

        # Check boundaries for safe indexing
        if not (radius <= row < rows - radius
            and radius <= col < cols - radius):
            continue

        for dRow in range(row - radius, row + radius + 1):
            for dCol in range(col - radius, col + radius + 1):
                if dRow == row and dCol == col: continue  # current spot
                var neighbor = get_coord_data(row=dRow, col=dCol)
                if neighbor > spot: cooler += 1

        if cooler > half_count:  # each spot has 8 neighbors
            print(t"Cool spot: ({row}, {col})")
            cool_indices.append((row, col))

    write_data()
```

<!-- markdownlint-enable MD013 -->

## What you touched

Representing a grid in a linear array, row-major indexing, tuple
unpacking, nested loops, coordinate arithmetic, chained comparisons,
neighborhood searches, simple visualization, and one of the most common
patterns in Advent of Code.
