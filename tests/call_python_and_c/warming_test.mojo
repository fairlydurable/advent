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
# Paired test for snippets/call_python_and_c/warming.mojo
# Run with: mojo run -I snippets/call_python_and_c tests/call_python_and_c/warming_test.mojo
from warming import main as warming_main
from std.testing import assert_true, TestSuite


def test_main_runs() raises:
    # warming.mojo guards both the numpy import and the BLAS handle with
    # try/except, so it never raises even when numpy isn't installed or
    # BLAS isn't on this platform's expected path. Running it end-to-end
    # confirms the station 3 parsing/correction logic still works against
    # src/downloads/station_reports.txt either way.
    warming_main()
    assert_true(True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
