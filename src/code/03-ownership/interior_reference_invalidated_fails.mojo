# EXPECT-ERROR: an element reference used after a call that can reallocate the List
# EXPECT-MATCH: use of invalidated interior reference
# Claim (3.11): element references carry the List's interior origin, and a
# `mut self` call such as `append` invalidates that origin.


def main():
    var names: List[String] = ["ada", "grace"]
    ref first = names[0]
    names.append("linus")
    print(first)
