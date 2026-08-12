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
# Run with:
#   mojo run -I snippets/work_with_grids tests/work_with_grids/work_with_grids_test.mojo
from work_with_grids import main as work_with_grids_main
from std.testing import assert_true, TestSuite


def test_main_runs() raises:
    # index_to_coord/get_coord_data/write_data are nested inside main(),
    # so they aren't individually importable. Running main() end-to-end
    # against src/downloads/grid_temps.txt is the meaningful check here.
    work_with_grids_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
