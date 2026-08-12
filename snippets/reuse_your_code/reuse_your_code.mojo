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
# ANCHOR: full
from toolkit import extract_ints, corrected, mean_of


def main() raises:
    print(t"reused: {extract_ints('readings: 3, 5, 8')}")  # [3, 5, 8]

    # ANCHOR: call_corrected
    print(t"noon, default: {corrected(24.5, 12)}")  # 23.0
    print(t"noon, bigger:  {corrected(24.5, 12, offset=2.0)}")  # 22.5
    # ANCHOR_END: call_corrected

    # ANCHOR: compose
    var raw: List[Float64] = [22.1, 24.5, 19.8]
    var hours = [9, 12, 16]
    var fixed = List[Float64]()
    for r, h in zip(raw, hours):
        fixed.append(corrected(r, h))
    print(t"corrected: {fixed}")  # [22.1, 23.0, 19.8]
    print(t"mean after correction: {round(mean_of(fixed), 2)}")  # 21.63
    # ANCHOR_END: compose


# ANCHOR_END: full
