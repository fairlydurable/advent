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
# Run with: mojo run -I snippets/mojo_basics tests/mojo_basics/analyzer.mojo
from analyzer import main as analyzer_main
from std.testing import assert_true, TestSuite


def test_analyzer_runs() raises:
    # analyzer.mojo has no reusable functions, just a print-driven main().
    # Importing and running it end-to-end is the meaningful check here.
    analyzer_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
