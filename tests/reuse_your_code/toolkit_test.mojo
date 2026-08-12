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
# Paired test for snippets/reuse_your_code/toolkit/__init__.mojo
# Run with: mojo run -I snippets/reuse_your_code tests/reuse_your_code/toolkit_test.mojo
from toolkit import extract_ints, corrected, mean_of
from std.testing import assert_almost_equal, assert_equal, TestSuite


def test_extract_ints() raises:
    assert_equal(extract_ints("readings: 3, 5, 8"), [3, 5, 8])


def test_corrected_default_offset_in_window() raises:
    assert_almost_equal(corrected(24.5, 12), 23.0, atol=1e-9)


def test_corrected_custom_offset() raises:
    assert_almost_equal(corrected(24.5, 12, offset=2.0), 22.5, atol=1e-9)


def test_corrected_outside_window_is_unchanged() raises:
    assert_almost_equal(corrected(24.5, 9), 24.5, atol=1e-9)
    assert_almost_equal(corrected(24.5, 14), 24.5, atol=1e-9)


def test_corrected_window_lower_bound_is_inclusive() raises:
    assert_almost_equal(corrected(24.5, 10), 23.0, atol=1e-9)


def test_mean_of() raises:
    var values: List[Float64] = [22.1, 23.0, 19.8]
    assert_almost_equal(mean_of(values), 21.6333333333, atol=1e-6)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
