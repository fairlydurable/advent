# EXPECT-ERROR: using a value that one path transferred away
# EXPECT-MATCH: uninitialized value 'job'
# Claim: after `^` on one branch, the binding counts as uninitialized at the
# merge point, so any later read fails to compile.
from std.sys import argv


def submit(var job: String):
    pass


def main():
    var job = String("nightly-backup")
    if len(argv()) > 0:
        submit(job^)
    print(job)
