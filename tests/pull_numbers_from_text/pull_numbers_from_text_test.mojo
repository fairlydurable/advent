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
# Paired test for snippets/pull_numbers_from_text/pull_numbers_from_text.mojo
# Run with:
#   mojo run -I snippets/pull_numbers_from_text \
#       tests/pull_numbers_from_text/pull_numbers_from_text_test.mojo
from pull_numbers_from_text import extract_ints, main as pull_numbers_main
from std.testing import assert_equal, assert_true, TestSuite


def test_extract_ints_basic() raises:
    assert_equal(extract_ints("a 1 b 22 c 333"), [1, 22, 333])


def test_extract_ints_no_digits() raises:
    assert_equal(extract_ints("no digits here"), List[Int]())


def test_extract_ints_empty_string() raises:
    assert_equal(extract_ints(""), List[Int]())


def test_extract_ints_run_at_end() raises:
    assert_equal(extract_ints("value 42"), [42])


def test_extract_ints_splits_on_sign_and_decimal() raises:
    # '-' and '.' aren't digits, so a decimal reading splits into two runs.
    assert_equal(extract_ints("-20.5"), [20, 5])


def test_main_runs() raises:
    pull_numbers_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
