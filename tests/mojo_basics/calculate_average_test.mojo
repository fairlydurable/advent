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
# Paired test for snippets/mojo_basics/calculate_average.mojo
# Run with: mojo run -I snippets/mojo_basics tests/mojo_basics/calculate_average.mojo
from calculate_average import calculate_average, main as calculate_average_main
from std.testing import assert_almost_equal, assert_true, TestSuite


def test_calculate_average() raises:
    var temps: List[Float64] = [-20.5, -22.3, -19.8, -25.1]
    assert_almost_equal(calculate_average(temps), -21.925, atol=1e-9)


def test_calculate_average_single_value() raises:
    var temps: List[Float64] = [-10.0]
    assert_almost_equal(calculate_average(temps), -10.0, atol=1e-9)


def test_main_runs() raises:
    calculate_average_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
