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


# ANCHOR: extract_ints
def extract_ints(text: String) raises -> List[Int]:
    var nums = List[Int]()
    var cur = String("")
    for i in range(text.byte_length()):
        var c = String(text[byte=i])
        if c >= "0" and c <= "9":  # an ASCII digit
            cur += c  # extend the current run
        elif cur:  # a run just ended
            nums.append(Int(cur))
            cur = String("")
    if cur:  # a run at the very end
        nums.append(Int(cur))
    return nums^


# ANCHOR_END: extract_ints


def main() raises:
    # ANCHOR: read_log
    var log = Path("src/downloads/temp_log.txt")
    var text = log.read_text()
    var lines = text.splitlines()
    print(text)
    # ANCHOR_END: read_log

    # ANCHOR: call_extract
    var found = extract_ints(text)
    print(t"found: {found}")
    # [1, 20, 5, 2, 22, 3, 3, 19, 8, 4, 25, 1, 5, 44, 5, 6, 27, 7, 7, 42, 3,
    #  8, 28, 2, 9, 23, 0, 10, 36, 5]
    # ANCHOR_END: call_extract

    # ANCHOR: filter_by_shape
    # Every line contributes three numbers: the day, the whole-degree part
    # of the temperature, and the tenths digit. Take every 3rd value.
    var day_numbers = List[Int]()
    for i in range(0, len(found), 3):
        day_numbers.append(found[i])
    print(t"day numbers: {day_numbers}")  # [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    # ANCHOR_END: filter_by_shape

    # ANCHOR: validate_sequence
    var expected = [i for i in range(1, len(lines) + 1)]
    print(t"complete, in order: {day_numbers == expected}")  # True
    # ANCHOR_END: validate_sequence

    # ANCHOR: decimal_breaks
    print(t"scanned: {extract_ints(String(lines[0]))}")  # [1, 20, 5]
    # ANCHOR_END: decimal_breaks

    # ANCHOR: decimal_reading
    var entry = lines[0].strip()  # 'Day 1: -20.5C, Partly Cloudy'
    var temp_field = entry.split(": ")[1].split(", ")[0]  # '-20.5C'
    var reading = Float64(temp_field.removesuffix("C"))
    print(t"reading: {reading}")  # -20.5
    # ANCHOR_END: decimal_reading
    # ANCHOR_END: final
