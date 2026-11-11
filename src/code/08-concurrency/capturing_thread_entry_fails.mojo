# EXPECT-ERROR: a C-ABI function cannot capture local state
# EXPECT-MATCH: cannot capture
# Claims:
#   - A thread entry point must be a C-ABI function, and a C-ABI function
#     cannot capture. Shared state has to travel through the opaque argument.
from threads import ThreadArg, erase, run_threads


def main():
    var hits = 0

    def bump(arg: ThreadArg) abi("C") {mut hits} -> ThreadArg:
        hits += 1
        return arg

    run_threads(bump, erase(hits), 4)
