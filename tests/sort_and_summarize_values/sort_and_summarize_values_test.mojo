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
# Paired test for snippets/sort_and_summarize_values/sort_and_summarize_values.mojo
# Run with:
#   mojo run -I snippets/sort_and_summarize_values \
#       tests/sort_and_summarize_values/sort_and_summarize_values_test.mojo
from sort_and_summarize_values import main as sort_and_summarize_values_main
from std.testing import assert_true, TestSuite


def test_main_runs() raises:
    # Every value here comes from src/downloads/station_reports.txt, so
    # this is a regression check that the sorting/reduction logic still
    # runs cleanly against the current data file.
    sort_and_summarize_values_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
