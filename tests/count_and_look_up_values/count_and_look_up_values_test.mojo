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
# Paired test for
# snippets/count_and_look_up_values/count_and_look_up_values.mojo
from count_and_look_up_values import main as count_and_look_up_values_main
from output import assert_prints, captured_output
from std.testing import TestSuite


def test_station_tallies() raises:
    var out = captured_output(count_and_look_up_values_main)

    assert_prints(out, "15 readings")
    assert_prints(out, "station 1: 5 readings")
    assert_prints(out, "station 3: 4 readings")
    assert_prints(out, "station 5: 6 readings")


def test_membership_checks() raises:
    var out = captured_output(count_and_look_up_values_main)

    assert_prints(out, "Station 1 reported? Yes")
    assert_prints(out, "Station 2 reported? No")
    assert_prints(out, "Station 4 reported? No")
    assert_prints(out, "silent stations: {2, 4}")


def test_missing_day_is_found() raises:
    # station_reports.txt deliberately omits Station 1 on Day 1.
    var out = captured_output(count_and_look_up_values_main)

    assert_prints(out, "missing days: [Station 1 - Day 1]")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
