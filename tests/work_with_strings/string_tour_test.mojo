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
# Paired test for snippets/work_with_strings/string_tour.mojo
# Run with:
#   mojo run -I snippets/work_with_strings tests/work_with_strings/string_tour_test.mojo
from string_tour import main as string_tour_main
from std.testing import assert_true, TestSuite


def test_main_runs() raises:
    # string_tour.mojo has no reusable functions; it walks the same
    # temp_log.txt line through trimming, slicing, searching, and casing
    # inline. Running it end-to-end confirms it still works against that
    # file's current first line.
    string_tour_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
