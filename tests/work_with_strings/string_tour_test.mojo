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
# Paired test for snippets/work_with_strings/string_tour.mojo
from output import assert_prints, captured_output
from std.testing import TestSuite
from string_tour import main as string_tour_main


def test_lengths_before_and_after_strip() raises:
    # 32 depends on the two trailing spaces on line 1 of temp_log.txt. If an
    # editor or formatter strips them, this fails instead of the page quietly
    # documenting the wrong number.
    var out = captured_output(string_tour_main)

    assert_prints(out, "length: 32")
    assert_prints(out, "cleaned: 'Day 1: -20.5C, Partly Cloudy', bytes: 28")


def test_join_variants() raises:
    var out = captured_output(string_tour_main)

    assert_prints(out, "'  Day 1: -20.5C, Partly Cloudy  '")
    assert_prints(out, "'Day1:-20.5C,PartlyCloudy'")
    assert_prints(out, "'H, e, l, l, o'")


def test_reversal_both_ways() raises:
    var out = captured_output(string_tour_main)

    assert_prints(out, "Reversed bytes: 'yduolC yltraP ,C5.02- :1 yaD'")
    assert_prints(out, "'yduolC yltraP ,C5.02- :1 yaD'")


def test_slicing_and_search() raises:
    var out = captured_output(string_tour_main)

    assert_prints(out, "byte prefix:     'Day 1'")
    assert_prints(out, "byte suffix:     'loudy'")
    assert_prints(out, "byte substring:  'y 1: -20'")
    assert_prints(out, "contains 'Day': True")
    assert_prints(out, "position of ':': 5")
    assert_prints(out, "position of '!': -1")
    assert_prints(out, "starts with 'Day': True")
    assert_prints(out, "ends with 'Cloudy': True")


def test_replace_split_and_case() raises:
    var out = captured_output(string_tour_main)

    assert_prints(out, "Day 1: -20.5C, Cloudy")
    assert_prints(out, "count: 2")
    assert_prints(out, "partly cloudy")
    assert_prints(out, "PARTLY CLOUDY")
    assert_prints(out, "'cloudy' matches: True")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
