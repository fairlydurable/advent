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
# Paired test for snippets/parse_text/parse_text.mojo
# Run with: mojo run -I snippets/parse_text tests/parse_text/parse_text_test.mojo
from parse_text import main as parse_text_main
from std.testing import assert_true, TestSuite


def test_main_runs() raises:
    # parse_text.mojo has no reusable functions; it walks through reading,
    # cleaning, and parsing src/downloads/temp_log.txt inline. Importing
    # and running it end-to-end confirms it still works against that file.
    parse_text_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
