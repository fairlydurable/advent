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
def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:
        raise Error("No temperature data")

    var total: Float64 = 0.0
    var count: Int = 0
    for temp in temps:
        total += temp
        count += 1
    return total / Float64(count)


# ANCHOR: main_raises
def main() raises:
    print("North Pole Temperature Analyzer")
    # ANCHOR_END: main_raises
    var temps: List[Float64] = [-20.5, -22.3, -19.8, -25.1]
    print(t"Recorded {len(temps)} temperatures")

    for index, temp in enumerate(temps):
        print(t"  Day {index + 1}: {temp}°C")

    # No try/except here, so a raised error escapes main()
    var avg = calculate_average(temps)
    print(t"Average: {round(avg, 2)}°C")  # Average: -21.92°C

    if avg > -20.0:
        print("Status: Hot week")
    elif avg > -25.0:
        print("Status: Comfortable week")  # Status: Comfortable week
    else:
        print("Status: Cool week")
