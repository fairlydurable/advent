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
# Paired test for snippets/parse_text/parse_text.mojo
from output import assert_prints, captured_output
from parse_text import main as parse_text_main
from std.testing import TestSuite


def test_line_counts() raises:
    var out = captured_output(parse_text_main)

    assert_prints(out, "Got 10 lines")
    # split("\n") keeps the trailing empty line that splitlines() drops.
    assert_prints(out, "split got 11 lines")


def test_parsed_temperatures() raises:
    var out = captured_output(parse_text_main)

    assert_prints(out, "temp: -20.5")
    assert_prints(
        out,
        (
            "Parsed 10 temperatures: [-20.5, -22.3, -19.8, -25.1, -44.5,"
            " -27.7, -42.3, -28.2, -23.0, -36.5]"
        ),
    )


def test_bad_reading_is_rejected() raises:
    var out = captured_output(parse_text_main)

    assert_prints(out, "Rejected 1: [Day 11: ERROR, Sensor Fault]")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
