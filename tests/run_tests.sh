#!/usr/bin/env bash
##===----------------------------------------------------------------------===##
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
##===----------------------------------------------------------------------===##
# Runs every paired test under tests/, importing its matching snippet
# module from the mirrored path under snippets/. Must run from the repo
# root (pixi run test does this for you).
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root" || exit 1

failures=0
count=0

while IFS= read -r -d '' test_file; do
    rel="${test_file#tests/}"
    snippet_dir="snippets/$(dirname "$rel")"
    count=$((count + 1))

    echo "--- $rel ---"
    if mojo run -I "$snippet_dir" "$test_file"; then
        echo "PASS: $rel"
    else
        echo "FAIL: $rel"
        failures=$((failures + 1))
    fi
    echo
done < <(find tests -name "*.mojo" -print0 | sort -z)

echo "Ran $count test files, $failures failed."
[ "$failures" -eq 0 ]
