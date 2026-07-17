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
