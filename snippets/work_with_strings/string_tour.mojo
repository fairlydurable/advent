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
    # ANCHOR: build_string
    var log = Path("src/downloads/temp_log.txt")
    var string: String = String(log.read_text().splitlines()[0])
    print(t"string: '{string}'")
    # single quotes make surrounding whitespace easy to spot
    # ANCHOR_END: build_string

    # ANCHOR: byte_length
    var length = string.byte_length()
    # ANCHOR_END: byte_length

    # ANCHOR: tstring_print
    print(t"{string} length: {length}")  # 32
    # ANCHOR_END: tstring_print

    # ANCHOR: iterate_chars
    print([String(t"'{slice}'") for slice in string.codepoint_slices()])
    # [' ', ' ', 'D', 'a', 'y', ' ', '1', ':', ' ', '-', '2', '0', '.', '5',
    #  'C', ',', ' ', 'P', 'a', 'r', 't', 'l', 'y', ' ', 'C', 'l', 'o',
    #  'u', 'd', 'y', ' ', ' ']
    # ANCHOR_END: iterate_chars

    # ANCHOR: join_all
    var joined = "".join([slice for slice in string.codepoint_slices()])
    print(t"'{joined}'")  # '  Day 1: -20.5C, Partly Cloudy  '
    # ANCHOR_END: join_all

    # ANCHOR: join_filtered
    joined = "".join(
        [slice for slice in string.codepoint_slices() if " " not in slice]
    )
    print(t"'{joined}'")  #  'Day1:-20.5C,PartlyCloudy'
    # ANCHOR_END: join_filtered

    # ANCHOR: join_hello
    var hello: String = "Hello"
    joined = ", ".join([slice for slice in hello.codepoint_slices()])
    print(t"'{joined}'")  # 'H, e, l, l, o'
    # ANCHOR_END: join_hello

    # ANCHOR: strip_edges
    var cleaned = string.strip()
    print(t"cleaned: '{cleaned}', bytes: {cleaned.byte_length()}")
    # ANCHOR_END: strip_edges

    # ANCHOR: strip_chars
    # Chiller flags critical readings with asterisks
    var flagged = "**" + cleaned + "**"
    print(t"'{flagged.strip("*")}'")  # 'Day 1: -20.5C, Partly Cloudy'
    # ANCHOR_END: strip_chars

    # ANCHOR: reverse_bytes
    var s: String = ""

    # construct and reverse the non-inclusive range
    for index in reversed(range(cleaned.byte_length())):
        s = s + String(cleaned[byte=index])
    print(t"Reversed bytes: '{s}'")  # 'yduolC yltraP ,C5.02- :1 yaD'
    # ANCHOR_END: reverse_bytes

    # ANCHOR: reverse_iterator
    # use the reversed iterator
    s = ""
    for slice in cleaned.codepoint_slices_reversed():
        s += String(slice)
    print(t"'{s}'")  # 'yduolC yltraP ,C5.02- :1 yaD'
    # ANCHOR_END: reverse_iterator

    # ANCHOR: byte_slicing
    # O(1) byte slicing to a view
    print(t"byte prefix:     '{cleaned[byte=:5]}'")  # 'Day 1'
    print(
        t"byte suffix:     '{cleaned[byte=cleaned.byte_length() - 5:]}'"
    )  # 'loudy'
    print(t"byte substring:  '{cleaned[byte=2:10]}'")  # 'y 1: -20'
    # ANCHOR_END: byte_slicing

    # ANCHOR: basic_search
    # Contains
    print(t"contains 'Day': {'Day' in cleaned}")  # True

    # Position
    print(t"position of ':': {cleaned.find(':')}")  # 7
    print(t"position of '!': {cleaned.find('!')}")  # -1, not found

    # Start and end
    print(t"starts with 'Day': {cleaned.startswith('Day')}")  # True
    print(t"ends with 'Cloudy': {cleaned.endswith('Cloudy')}")  # True
    # ANCHOR_END: basic_search

    # ANCHOR: find_truthy_trap
    if cleaned.find("!"):
        print("-1 is truthy")  # This prints
    else:
        print("You'd expect to be here, but you're not")
    # ANCHOR_END: find_truthy_trap

    # ANCHOR: in_correct_check
    if "!" in cleaned:
        print("Found")
    else:
        print("Not found")  # This prints
    # ANCHOR_END: in_correct_check

    # ANCHOR: empty_truthiness
    if "":
        print("Won't be printed")
    elif "🔥":
        print("This is printed")
    # ANCHOR_END: empty_truthiness

    # ANCHOR: process_text
    if cleaned:
        # There's something to process.
        print(t"Processing: '{cleaned}'")
    # ANCHOR_END: process_text

    # ANCHOR: replace_text
    var standardized = cleaned.replace("Partly Cloudy", "Cloudy")
    var no_units = standardized.replace("C", "")
    print(standardized)
    print(no_units)  # loudy! Maybe not a great idea
    # ANCHOR_END: replace_text

    # ANCHOR: split_fields
    var parts = cleaned.split(", ")
    print(t"split on ', ': {parts}")  # [Day 1: -20.5C, Partly Cloudy]
    print(t"count: {len(parts)}")  # 2
    # ANCHOR_END: split_fields

    # ANCHOR: case_conversion
    print(parts[1].lower())  # partly cloudy
    print(parts[1].upper())  # PARTLY CLOUDY
    # ANCHOR_END: case_conversion

    # ANCHOR: case_insensitive_match
    print(t"'cloudy' matches: {'cloudy' in cleaned.lower()}")  # True
    # ANCHOR_END: case_insensitive_match
    # ANCHOR_END: final
