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
# ANCHOR: final
from std.pathlib import Path

# ANCHOR: numpy_import
from std.python import Python

# ANCHOR_END: numpy_import

# ANCHOR: blas_import
from std.ffi import OwnedDLHandle, c_int, c_double

# ANCHOR_END: blas_import


def main() raises:
    # ANCHOR: first_program
    var log = Path("src/downloads/station_reports.txt")
    var lines = log.read_text().splitlines()

    var days = List[Int]()
    var readings = List[Float64]()

    for line in lines:
        # ['Station 3', 'Day 0', '06:00', '-22.3C', 'Clear']
        var fields = line.split(", ")
        if String(fields[0]) != "Station 3":
            continue

        var hour = Int(fields[2].split(":")[0])
        var temp = Float64(fields[3].removesuffix("C"))

        # station 3 bakes in solar loading between 10:00 and 14:00
        if 10 <= hour < 14:
            temp -= 1.5

        days.append(Int(fields[1].split(" ")[1]))
        readings.append(temp)

    print(t"{len(readings)} station 3 readings")  # 4 station 3 readings
    # ANCHOR_END: first_program

    # ANCHOR: numpy_fit
    try:
        var np = Python.import_module("numpy")

        var xs = Python.list()
        for d in days:
            xs.append(d)
        var ys = Python.list()
        for r in readings:
            ys.append(r)

        var fit = np.polyfit(xs, ys, 1)  # [slope, intercept]
        var slope = fit[0]  # degrees per day
        print(t"trend: {slope} C/day")  # ~1.91, rising
        print(t"warming? {slope > 0}")  # True
    except:
        print("numpy not found. Add it with `pixi add numpy`.")
    # ANCHOR_END: numpy_fit

    # ANCHOR: blas_reduce
    try:
        var blas = OwnedDLHandle(
            "/System/Library/Frameworks/Accelerate.framework/Accelerate"
        )
        comptime origin = origin_of(readings)

        # cblas_dasum(count, X, stride) sums |X| in one C call
        var dasum = blas.borrow().get_function[
            def(
                c_int, Pointer[c_double, origin], c_int
            ) thin abi("C") -> c_double
        ]("cblas_dasum")

        var total = dasum(c_int(len(readings)), readings.unsafe_ptr(), c_int(1))
        # every station 3 reading is below zero, so the magnitude sum
        # negates back to the real mean
        print(t"season mean: {-total / Float64(len(readings))}")  # -20.55
        _ = blas  # keep the handle alive to the end of the call
    except:
        print("BLAS not found.")
    # ANCHOR_END: blas_reduce
    # ANCHOR_END: final
