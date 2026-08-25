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
# ANCHOR: read_log
# ANCHOR: final
from std.pathlib import Path


def main() raises:
    var log = Path("src/downloads/temp_log.txt")
    print(log.read_text())  # Day 1: -20.5C, Partly Cloudy, etc
    # ANCHOR_END: read_log

    # ANCHOR: check_log
    print(t"Exists: {log.exists()}")
    print(t"File:   {log.is_file()}")
    print(t"Dir:    {log.is_dir()}")
    # ANCHOR_END: check_log

    # ANCHOR: split_lines
    var text = log.read_text()
    var lines = text.splitlines()
    print(t"Got {len(lines)} lines")  # Got 10 lines
    # ANCHOR_END: split_lines

    # ANCHOR: create_report
    var report = Path("report.txt")

    report.write_text(
        String(
            "North Pole Temperature Report",
            "=============================",
            "",
            "Input: temp_log.txt",
            "Status: Received",
            "",
            "Waiting for analysis...",
            "",
            sep="\n",
        )
    )
    # ANCHOR_END: create_report

    # ANCHOR: append_report
    with open(report, "a") as f:
        var value = -52.3
        f.write(t"\nLate reading: {Float64(value)} °C")
    print(report.read_text())
    # ANCHOR_END: append_report

    # ANCHOR: cleanup_report
    from std.os import remove

    try:
        if report.exists():
            remove(report)
    except e:
        print(t"File removal failed: {e}")

    print(t"After cleanup, exists: {report.exists()}")
    # ANCHOR_END: cleanup_report
    # ANCHOR_END: final
