# EXPECT-ERROR: an element reference held across a mut call on its List
# EXPECT-MATCH: use of invalidated interior reference
# Claim (3.4): any `mut self` call on a List invalidates element references,
# even `reserve(1)`, which never reallocates a list that already holds two.


def main():
    var names: List[String] = ["ada", "grace"]
    ref first = names[0]
    names.reserve(1)
    print(first)
