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
# Paired test for snippets/work_with_files/temp_log.mojo
# Run with: mojo run -I snippets/work_with_files tests/work_with_files/temp_log_test.mojo
from temp_log import main as temp_log_main
from std.pathlib import Path
from std.testing import assert_true, TestSuite


def test_main_cleans_up_report() raises:
    # temp_log.mojo creates report.txt, appends to it, then removes it.
    # The real, assertable behavior here is that cleanup actually happens.
    temp_log_main()
    assert_true(not Path("report.txt").exists())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
