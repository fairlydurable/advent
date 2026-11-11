# EXPECT-ERROR: merging a mutable and an immutable pointer yields an immutable one
# EXPECT-MATCH: must be mutable
# Claim (3.8): a union origin is mutable only when every member is mutable.


def main():
    var north = String("north")
    var south = String("south")
    var heading_north = True
    var heading = (
        Pointer(to=north) if heading_north else Pointer(to=south).as_imm()
    )
    heading[] += "!"
