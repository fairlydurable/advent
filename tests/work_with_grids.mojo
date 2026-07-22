# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #
def main():
    var data = [
        6,
        13,
        6,
        9,
        8,
        14,
        3,
        9,
        10,
        11,
        14,
        11,
        10,
        8,
        9,
        9,
        6,
        6,
        8,
        14,
        6,
        12,
        11,
        3,
        4,
        7,
        7,
        4,
        14,
        7,
        8,
        6,
        5,
        8,
        6,
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
        var row, col = index_to_coord(index)  # fetch the row and column
        var cooler = 0  # keeps a running comparison count
        var spot = get_coord_data(row=row, col=col)  # the current spot's value

        # Check boundaries for safe indexing
        if not (
            radius <= row < rows - radius and radius <= col < cols - radius
        ):
            continue

        for dRow in range(row - radius, row + radius + 1):
            for dCol in range(col - radius, col + radius + 1):
                if dRow == row and dCol == col:
                    continue  # current spot
                var neighbor = get_coord_data(row=dRow, col=dCol)
                if neighbor > spot:
                    cooler += 1

        if cooler > half_count:  # each spot has 8 neighbors
            print(t"Cool spot: ({row}, {col})")
            cool_indices.append((row, col))

    write_data()
