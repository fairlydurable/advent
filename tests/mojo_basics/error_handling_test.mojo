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
# Paired test for snippets/mojo_basics/error_handling.mojo
# Run with: mojo run -I snippets/mojo_basics tests/mojo_basics/error_handling.mojo
from error_handling import calculate_average, main as error_handling_main
from output import assert_prints, captured_output
from std.testing import (
    assert_almost_equal,
    assert_raises,
    assert_true,
    TestSuite,
)


def test_calculate_average() raises:
    var temps: List[Float64] = [-20.5, -22.3, -19.8, -25.1]
    assert_almost_equal(calculate_average(temps), -21.925, atol=1e-9)


def test_calculate_average_raises_on_empty() raises:
    var empty = List[Float64]()
    with assert_raises(contains="No temperature data"):
        _ = calculate_average(empty)


def test_main_output() raises:
    var out = captured_output(error_handling_main)

    assert_prints(out, "Recorded 4 temperatures")
    assert_prints(out, "Average: -21.92°C")
    assert_prints(out, "Status: Comfortable week")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
