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
# Paired test for
# snippets/count_and_look_up_values/count_and_look_up_values.mojo
# Run with:
#   mojo run -I snippets/count_and_look_up_values \
#       tests/count_and_look_up_values/count_and_look_up_values_test.mojo
from count_and_look_up_values import main as count_and_look_up_values_main
from std.testing import assert_true, TestSuite


def test_main_runs() raises:
    # The tallies, membership checks, and missing-day comprehension all
    # depend on src/downloads/station_reports.txt staying in the shape
    # the page describes; running it end-to-end catches drift there.
    count_and_look_up_values_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
