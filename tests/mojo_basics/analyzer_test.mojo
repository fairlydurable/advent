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
# Paired test for snippets/mojo_basics/analyzer.mojo
from analyzer import main as analyzer_main
from output import assert_prints, captured_output
from std.testing import TestSuite


def test_analyzer_report() raises:
    var out = captured_output(analyzer_main)

    assert_prints(out, "North Pole Temperature Analyzer")
    assert_prints(out, "Recorded 4 temperatures")
    assert_prints(out, "  Day 1: -20.5°C")
    assert_prints(out, "  Day 4: -25.1°C")
    assert_prints(out, "All temps negative")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
