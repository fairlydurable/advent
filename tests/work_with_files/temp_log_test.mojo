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
from output import assert_prints, captured_output
from std.pathlib import Path
from std.testing import assert_true, TestSuite
from temp_log import main as temp_log_main


def test_reads_and_inspects_the_log() raises:
    var out = captured_output(temp_log_main)

    assert_prints(out, "Exists: True")
    assert_prints(out, "File:   True")
    assert_prints(out, "Dir:    False")
    assert_prints(out, "Got 10 lines")


def test_writes_then_appends_the_report() raises:
    var out = captured_output(temp_log_main)

    assert_prints(out, "North Pole Temperature Report")
    assert_prints(out, "Input: temp_log.txt")
    assert_prints(out, "Status: Received")
    assert_prints(out, "Late reading: -52.3 °C")


def test_main_cleans_up_report() raises:
    # temp_log.mojo creates report.txt, appends to it, then removes it.
    var out = captured_output(temp_log_main)

    assert_prints(out, "After cleanup, exists: False")
    assert_true(not Path("report.txt").exists())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
