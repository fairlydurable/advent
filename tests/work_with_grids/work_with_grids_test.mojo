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
# Paired test for snippets/work_with_grids/work_with_grids.mojo
from output import assert_prints, captured_output
from std.testing import TestSuite
from work_with_grids import main as work_with_grids_main


def test_grid_renders_every_row() raises:
    var out = captured_output(work_with_grids_main)

    assert_prints(out, " -30  -25  -28  -32  -20  -15   -3")
    assert_prints(out, " -22  -18   -5  -20  -15  -10  -11")
    assert_prints(out, " -27  -20  -30  -22  -17  -18  -19")
    assert_prints(out, " -19   -3  -32  -31  -16  -10  -11")
    assert_prints(out, " -24  -30  -22  -30  -19   -9   -8")


def test_cool_spots_found() raises:
    var out = captured_output(work_with_grids_main)

    assert_prints(out, "Cool spot: (2, 2)")
    assert_prints(out, "Cool spot: (2, 3)")
    assert_prints(out, "Cool spot: (2, 5)")
    assert_prints(out, "Cool spot: (3, 2)")
    assert_prints(out, "Cool spot: (3, 3)")


def test_second_pass_flags_the_cool_spots() raises:
    # Same two rows as above, now starred where a cool spot was found.
    var out = captured_output(work_with_grids_main)

    assert_prints(out, " -27  -20  -30* -22* -17  -18* -19")
    assert_prints(out, " -19   -3  -32* -31* -16  -10  -11")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
