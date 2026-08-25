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
# Test helper, not book content. Snippets keep their work inside main() and
# report by printing, so the only way to check what a page claims is to read
# what the snippet actually wrote to stdout.
#
# This uses dup/dup2 from std.sys._libc and stdout from std.sys._io. Both are
# private stdlib modules and can move without notice; std.testing.assert_aborts
# redirects the same way. If an import here breaks after a nightly bump, that
# is the cause.
from std.pathlib import Path
from std.sys._io import stdout
from std.sys._libc import close, dup, dup2
from std.tempfile import NamedTemporaryFile
from std.testing import assert_true


def captured_output(f: Some[def() raises]) raises -> String:
    """Runs `f` with stdout redirected, and returns everything it printed."""
    var saved = dup(Int32(stdout.value))
    var text: String

    with NamedTemporaryFile("rw") as sink:
        _ = dup2(Int32(sink._file_handle._get_raw_fd()), Int32(stdout.value))
        try:
            f()
        finally:
            # Restore stdout before reading, so a failure can still report.
            _ = dup2(saved, Int32(stdout.value))
            _ = close(saved)
        text = Path(sink.name).read_text()

    return text^


def assert_prints(output: String, expected: String) raises:
    """Asserts the snippet printed `expected` somewhere in `output`."""
    assert_true(
        expected in output,
        msg=String(
            t"the page documents '{expected}', which the snippet did not"
            t" print.\n--- actual output ---\n{output}"
        ),
    )
