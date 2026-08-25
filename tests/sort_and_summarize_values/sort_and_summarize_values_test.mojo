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
# Paired test for snippets/sort_and_summarize_values/sort_and_summarize_values.mojo
# Run with:
#   mojo run -I snippets/sort_and_summarize_values -I tests/support \
#       tests/sort_and_summarize_values/sort_and_summarize_values_test.mojo
from output import assert_prints, captured_output
from sort_and_summarize_values import main as sort_and_summarize_values_main
from std.testing import TestSuite


def test_documented_values() raises:
    # Every string here is a value the page prints as a trailing comment.
    var out = captured_output(sort_and_summarize_values_main)

    assert_prints(out, "15 readings")
    assert_prints(
        out,
        (
            "sorted: [-41.7, -32.0, -31.5, -30.1, -29.0, -28.4, -24.0, -23.1,"
            " -22.3, -22.3, -21.7, -21.0, -20.5, -18.5, -18.2]"
        ),
    )
    assert_prints(out, "coldest: -41.7, warmest: -18.2")
    assert_prints(out, "top 3 warmest: [-20.5, -18.5, -18.2]")
    assert_prints(out, "average: -25.6")
    assert_prints(out, "extreme readings: [-30.1, -31.5, -32.0, -41.7]")


def test_extremes_trace_back_to_their_stations() raises:
    # The point of keeping `labels` alongside `readings`: index() has to land
    # on the station and day that produced each extreme.
    var out = captured_output(sort_and_summarize_values_main)

    assert_prints(out, "Coldest reading: Station 5, Day 2, 18:00 at -41.7°C")
    assert_prints(out, "Warmest reading: Station 3, Day 2, 06:00 at -18.2°C")


def test_zip_pairs_every_reading_with_its_label() raises:
    var out = captured_output(sort_and_summarize_values_main)

    # First and last rows of the zip loop, in file order.
    assert_prints(out, "Station 3, Day 0, 06:00: -22.3")
    assert_prints(out, "Station 1, Day 2, 18:00: -24.0")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
