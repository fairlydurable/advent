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
# ANCHOR: extract_ints
def extract_ints(text: String) raises -> List[Int]:
    var nums = List[Int]()
    var cur = String("")
    for i in range(text.byte_length()):
        var c = String(text[byte=i])
        if c >= "0" and c <= "9":
            cur += c
        elif cur:
            nums.append(Int(cur))
            cur = String("")
    if cur:
        nums.append(Int(cur))
    return nums^


# ANCHOR_END: extract_ints


# ANCHOR: corrected
def corrected(reading: Float64, hour: Int, offset: Float64 = 1.5) -> Float64:
    # station 3 bakes in solar loading between 10:00 and 14:00
    if 10 <= hour < 14:
        return reading - offset
    return reading


# ANCHOR_END: corrected


# ANCHOR: mean_of
def mean_of(values: List[Float64]) -> Float64:
    var total = 0.0
    for v in values:
        total += v
    return total / Float64(len(values))


# ANCHOR_END: mean_of
# ANCHOR_END: full
