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
    # ANCHOR: read_lines
    var log = Path("src/downloads/temp_log.txt")
    var text = log.read_text()
    var lines = text.splitlines()
    print(t"Got {len(lines)} lines")  # Got 10 lines
    # ANCHOR_END: read_lines

    # ANCHOR: split_vs_splitlines
    var split_on_newline = text.split("\n")
    print(t"split got {len(split_on_newline)} lines")  # 11 lines
    # ANCHOR_END: split_vs_splitlines

    # ANCHOR: strip_and_skip
    var cleaned_lines: List[String] = []
    for line in lines:
        var cleaned = line.strip()
        if not cleaned:
            continue
        cleaned_lines.append(String(cleaned))
        print(t"line: '{cleaned}'")
    # ANCHOR_END: strip_and_skip

    # ANCHOR: extract_fields
    var first = cleaned_lines[0]
    var reading = first.split(": ")[1].split(", ")
    var temp_field = reading[0]  # '-20.5C'
    var conditions = reading[1]  # 'Partly Cloudy'
    print(t"temp field: '{temp_field}', conditions: '{conditions}'")
    # ANCHOR_END: extract_fields

    # ANCHOR: naive_float_fails
    try:
        _ = Float64(temp_field)
    except e:
        print(t"Float64('{temp_field}') raised: {e}")
    # ANCHOR_END: naive_float_fails

    # ANCHOR: strip_units
    var temp = Float64(temp_field.removesuffix("C"))
    print(t"temp: {temp}")  # -20.5
    # ANCHOR_END: strip_units

    # ANCHOR: convert_to_float
    var temps: List[Float64] = []

    for line in cleaned_lines:
        var fields = line.split(": ")[1].split(", ")
        temps.append(Float64(fields[0].removesuffix("C")))

    print(t"Parsed {len(temps)} temperatures: {temps}")
    # ANCHOR_END: convert_to_float

    # ANCHOR: inject_bad_reading
    # Simulate one more reading coming in from a flaky sensor
    var extended_lines = cleaned_lines.copy()
    extended_lines.append("Day 11: ERROR, Sensor Fault")
    # ANCHOR_END: inject_bad_reading

    # ANCHOR: handle_invalid
    temps = []
    var rejected: List[String] = []

    for line in extended_lines:
        var fields = line.split(": ")[1].split(", ")

        try:
            temps.append(Float64(fields[0].removesuffix("C")))
        except:
            rejected.append(line)

    print(t"Parsed {len(temps)} temperatures: {temps}")
    print(t"Rejected {len(rejected)}: {rejected}")
    # ANCHOR_END: handle_invalid

    # ANCHOR: except_with_error
    for line in extended_lines:
        var fields = line.split(": ")[1].split(", ")

        try:
            _ = Float64(fields[0].removesuffix("C"))
        except e:
            print(t"Rejected '{line}': {e}")
    # ANCHOR_END: except_with_error

    # ANCHOR: split_columns
    var row = cleaned_lines[5]  # 'Day 6: -27.7C,   Foggy'
    var columns = row.split(",")
    print(columns)  # [Day 6: -27.7C,    Foggy]
    # ANCHOR_END: split_columns
    # ANCHOR_END: final
