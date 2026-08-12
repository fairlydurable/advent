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
# Run with:
#   mojo run -I snippets/reuse_your_code tests/reuse_your_code/reuse_your_code_test.mojo
from reuse_your_code import main as reuse_your_code_main
from std.testing import assert_true, TestSuite


def test_main_runs() raises:
    # reuse_your_code.mojo only demonstrates calling into the toolkit
    # library (covered directly in toolkit_test.mojo); running it end to
    # end confirms the two stay wired together correctly.
    reuse_your_code_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
