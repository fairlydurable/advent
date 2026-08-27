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
from std.python.numpy import copy_to_numpy_array, from_numpy_array

# ANCHOR_END: numpy_import

# ANCHOR: blas_import
from std.ffi import OwnedDLHandle, c_int, c_double

# ANCHOR_END: blas_import


def main() raises:
    # ANCHOR: first_program
    var log = Path("src/downloads/station_reports.txt")
    var lines = log.read_text().splitlines()

    var days: List[Int64] = []
    var readings: List[Float64] = []

    for line in lines:
        # ['Station 3', 'Day 0', '06:00', '-22.3C', 'Clear']
        var fields = line.split(", ")
        if String(fields[0]) != "Station 3":
            continue

        try:
            var dayString = String(fields[1].split(" ")[1])
            var day = Int64(atol(dayString))
            days.append(day)

            var hourString = String(fields[2].split(":")[0])
            var temperatureString = String(fields[3].removesuffix("C"))
            var temperature = Float64(atof(temperatureString))

            # Station 3 bakes in solar loading between 10:00 and 14:00
            if Float64(10) <= Float64(hourString) < Float64(14):
                temperature -= 1.5

            readings.append(temperature)

        except e:
            print(t"Unable to convert text to data: {e}")

    print("Warming report")
    print(t"Readings:    {len(readings)} (Station 3 only)")  # Four readings
    # ANCHOR_END: first_program

    # ANCHOR: numpy_fit
    # Converts True/False to "Yes"/"No"
    var truth_string = lambda (b: Bool) -> String: ("Yes" if b else "No")

    try:
        var np = Python.import_module("numpy")
        var xs = copy_to_numpy_array(days)
        var ys = copy_to_numpy_array(readings)

        var fit = np.polyfit(xs, ys, 1)  # [slope, intercept]
        var slope = Float64(py=fit[0])  # degrees per day

        print(t"Trend:       {round(slope, 2)} C/day")  # ~1.91, rising
        print(t"Warming?:    {truth_string(slope > 0)}")  # Yes
    except:
        print("numpy not found. Add it with `pixi add numpy`.")
    # ANCHOR_END: numpy_fit

    # ANCHOR: blas_reduce
    try:
        var blas = OwnedDLHandle(
            "/System/Library/Frameworks/Accelerate.framework/Accelerate"
        )

        # Keep readings alive
        comptime origin = origin_of(readings)

        # cblas_dasum(count, X, stride) sums |X| in one C call
        var dasum = blas.borrow().get_function[
            def(
                c_int, Pointer[c_double, origin], c_int
            ) thin abi("C") -> c_double
        ]("cblas_dasum")

        var total = dasum(c_int(len(readings)), readings.unsafe_ptr(), c_int(1))
        var mean = total / Float64(len(readings))

        # Every Station 3 reading is below zero, so the magnitude sum
        # negates back to the real mean
        print(t"season mean: {round(-mean, 2)}")  # -20.55
    except:
        print("BLAS not found.")
    # ANCHOR_END: blas_reduce
    # ANCHOR_END: final
