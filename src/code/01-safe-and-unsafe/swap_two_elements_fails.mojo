# EXPECT-ERROR: two element references from one List passed to mut arguments of one call
# EXPECT-MATCH: aliasing values passed mutably
# Claim: the exclusivity check treats every element of a List as part of
# one origin, so `swap` can't take two of its elements at once.
def main():
    var queue: List[String] = ["ingest", "transform", "publish"]
    swap(queue[0], queue[2])
