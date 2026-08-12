# ===----------------------------------------------------------------------=== #
# Copyright (c) 2026, Modular Inc. All rights reserved.
#
# Licensed under the Apache License v2.0 with LLVM Exceptions:
# https://llvm.org/LICENSE.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===----------------------------------------------------------------------=== #
# ANCHOR: final
from std.pathlib import Path


def main() raises:
    # ANCHOR: data_setup
    var log = Path("src/downloads/grid_temps.txt")
    var lines = log.read_text().splitlines()

    var rows = len(lines)
    var cols = lines[0].byte_length() / 2
    var data = List[Int]()

    for line in lines:
        for i in range(0, line.byte_length(), 2):
            var pair = line[byte = i : i + 2]
            data.append(-Int(String(pair)))
    # ANCHOR_END: data_setup

    # ANCHOR: helpers
    def index_to_coord(index: Int) {imm} -> Tuple[Int, Int]:
        return (index / cols, index % cols)

    def get_coord_data(row: Int, col: Int) {imm} -> Int:
        return data[row * cols + col]

    # ANCHOR_END: helpers

    # ANCHOR: cool_indices
    var cool_indices: List[Tuple[Int, Int]] = []
    # ANCHOR_END: cool_indices

    # ANCHOR: write_data
    # Write the data in a grid format
    def write_data() {imm data, imm cool_indices, imm}:
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

    # ANCHOR_END: write_data

    # ANCHOR: initial_print
    write_data()
    # ANCHOR_END: initial_print

    # ANCHOR: search_params
    var radius = 1  # how far to look
    var count = (radius * 2 + 1) ** 2 - 1  # how many neighbors?
    var half_count = count / 2  # half of the neighbors
    # ANCHOR_END: search_params

    # ANCHOR: search_loop
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

        # ANCHOR: mark_cool
        if cooler > half_count:  # each spot has 8 neighbors
            print(t"Cool spot: ({row}, {col})")
            # ANCHOR_END: search_loop
            cool_indices.append((row, col))
    # ANCHOR_END: mark_cool

    # ANCHOR: final_call
    write_data()
    # ANCHOR_END: final_call
    # ANCHOR_END: final
