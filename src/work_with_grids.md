# Work with grids 🔥

Your puzzle lays the sensors out as a grid and asks for the cold spots. Here's
what you need: store a grid, walk every cell, and check its neighbors.

## The sensor field

The sensors sit in a rectangular field, one integer reading per cell. Store the
field as a list of rows, where each row is itself a list.

Create `grid.mojo`:

```mojo
def main() raises:
    var grid: List[List[Int]] = [
        [8, 7, 8, 9],
        [7, 5, 6, 8],
        [8, 6, 7, 9],
    ]
    var rows = len(grid)
    var cols = len(grid[0])
    print(t"grid is {rows} x {cols}")  # grid is 3 x 4
```

### Checkpoint

- `List[List[Int]]` is a grid: an outer list of rows, each an inner list of
  cells.
- `grid[r][c]` reads row `r`, column `c`. Rows first, then columns.
- `len(grid)` counts the rows; `len(grid[0])` counts the columns of the first
  row. This assumes every row has the same length.

## Walk every cell

Two nested loops visit the whole grid, the outer over rows and the inner over
columns. Add this to `main()`:

```mojo
    for r in range(rows):
        for c in range(cols):
            print(t"({r}, {c}) = {grid[r][c]}", end="  ")
        print()  # newline at the end of each row
```

### Checkpoint

- The outer loop picks a row, the inner loop walks that row's columns.
- `(r, c)` is the coordinate of the current cell, the pair you use for every grid
  lookup.

## Check the neighbors

Most grid puzzles compare a cell to its neighbors. Keep the four directions in
one list of offsets, then add each offset to the current coordinate.

```mojo
    var deltas: List[Tuple[Int, Int]] = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    for d in deltas:
        var dr, dc = d
        var nr = 1 + dr  # neighbors of cell (1, 1)
        var nc = 1 + dc
        if 0 <= nr < rows and 0 <= nc < cols:  # stay on the grid
            print(t"neighbor ({nr}, {nc}) = {grid[nr][nc]}")
```

### Checkpoint

- A delta list holds the directions once, so the scan reads the same for all four
  neighbors. Add diagonals with four more offsets.
- `0 <= nr < rows` is a chained comparison, one test that both ends pass.
- Guard the bounds *before* you index. A coordinate off the edge is not a cell.

## Find the cold spots

A cold spot is a cell strictly colder than every neighbor it has. Combine the
walk, the deltas, and the bounds check into one scan:

```mojo
    for r in range(rows):
        for c in range(cols):
            var here = grid[r][c]
            var is_cold = True
            for d in deltas:
                var dr, dc = d
                var nr = r + dr
                var nc = c + dc
                if 0 <= nr < rows and 0 <= nc < cols:
                    if grid[nr][nc] <= here:
                        is_cold = False
            if is_cold:
                print(t"cold spot at ({r}, {c}): {here}")  # (1, 1): 5
```

### Checkpoint

- The cell stays a cold spot only while every in-bounds neighbor is strictly
  warmer. One neighbor that ties or beats it flips `is_cold` off.
- Edge cells simply have fewer neighbors, and the bounds check handles that for
  free.
- This walk-and-compare-neighbors shape solves a whole family of grid puzzles,
  not just cold spots.

## Final code

Your complete `grid.mojo`:

```mojo
def main() raises:
    var grid: List[List[Int]] = [
        [8, 7, 8, 9],
        [7, 5, 6, 8],
        [8, 6, 7, 9],
    ]
    var rows = len(grid)
    var cols = len(grid[0])
    print(t"grid is {rows} x {cols}")  # grid is 3 x 4

    var deltas: List[Tuple[Int, Int]] = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    for r in range(rows):
        for c in range(cols):
            var here = grid[r][c]
            var is_cold = True
            for d in deltas:
                var dr, dc = d
                var nr = r + dr
                var nc = c + dc
                if 0 <= nr < rows and 0 <= nc < cols:  # stay on the grid
                    if grid[nr][nc] <= here:
                        is_cold = False
            if is_cold:
                print(t"cold spot at ({r}, {c}): {here}")  # (1, 1): 5
```

## What you touched

Nested lists as a grid, row-major indexing, nested loops to walk every cell,
coordinate deltas held in a list, tuple unpacking, chained comparisons for bounds
checks, and the walk-and-check-neighbors pattern.

Next, you stop rewriting the same parsing and scanning by hand, and fold it into
functions you reuse across every puzzle.
