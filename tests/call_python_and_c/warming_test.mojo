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
# Paired test for snippets/call_python_and_c/warming.mojo
from output import assert_prints, captured_output
from std.testing import TestSuite
from warming import main as warming_main


def test_station_three_trend() raises:
    # Needs Python and a resident BLAS, same as the page's walkthrough.
    var out = captured_output(warming_main)

    assert_prints(out, "4 station 3 readings")
    assert_prints(out, "trend: 1.909")
    assert_prints(out, "warming? True")
    assert_prints(out, "season mean: -20.5")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
