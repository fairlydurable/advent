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
# ANCHOR: hello
# ANCHOR: list
def main():
    print("North Pole Temperature Analyzer")
    # ANCHOR_END: hello

    # Square brackets tell Mojo the `List` type at compile time
    var temps: List[Float64] = [-20.5, -22.3, -19.8, -25.1]

    print(t"Recorded {len(temps)} temperatures")  # TStrings are templates
    # ANCHOR_END: list

    # ANCHOR: for_in
    for index in range(len(temps)):  # The range is [0, len(temps))
        print(t"  Day {index + 1}: {temps[index]}°C")
    # ANCHOR_END: for_in

    # ANCHOR: enumerate
    for index, temp in enumerate(temps):
        print(t"  Day {index + 1}: {temp}°C")
    # ANCHOR_END: enumerate

    # ANCHOR: for_else
    for _, temp in enumerate(temps):
        if temp > 0.0:
            break
    else:
        print("All temps negative")
    # ANCHOR_END: for_else
