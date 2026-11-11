# EXPECT-EXIT: nonzero
# Claims:
# - `abort` terminates the process without unwinding. Destructors on the
#   path to `abort` do not run, even for a value whose last use comes before
#   the call (here `audit` is last read while building the message). A
#   destructor is not a place for work that must survive a crash, such as
#   flushing a journal or releasing a lock file.
# - Expected output: "audit open", then the abort message. The line
#   "audit flushed" never appears.
from std.os import abort


struct AuditLog(Movable):
    var path: String

    def __init__(out self, path: String):
        self.path = path
        print("audit open")

    def __deinit__(deinit self):
        print("audit flushed")


def main():
    var audit = AuditLog("/var/log/payments.audit")
    abort(String("cannot continue with ", audit.path))
