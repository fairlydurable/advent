# EXPECT-ERROR: Atomic has no copy; a copy would be a second, unrelated counter
# EXPECT-MATCH: no attribute 'copy'
# Claims:
#   - Atomic is not Copyable. It is still Movable, so the program must not
#     move one while another thread holds its address.
from std.atomic import Atomic


def main():
    var connections = Atomic[Int64](0)
    var snapshot = connections.copy()
