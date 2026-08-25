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
# Paired test for snippets/reuse_your_code/reuse_your_code.mojo
from output import assert_prints, captured_output
from reuse_your_code import main as reuse_your_code_main
from std.testing import TestSuite


def test_toolkit_calls_from_the_page() raises:
    var out = captured_output(reuse_your_code_main)

    assert_prints(out, "reused: [3, 5, 8]")


def test_default_and_overridden_offset() raises:
    # corrected() takes offset=1.5 by default; the page overrides it to 2.0.
    var out = captured_output(reuse_your_code_main)

    assert_prints(out, "noon, default: 23.0")
    assert_prints(out, "noon, bigger:  22.5")


def test_composed_correction_and_mean() raises:
    var out = captured_output(reuse_your_code_main)

    assert_prints(out, "corrected: [22.1, 23.0, 19.8]")
    assert_prints(out, "mean after correction: 21.63")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
