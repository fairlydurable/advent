# EXPECT-ERROR: an immutable pointer cannot convert back to a mutable one
# EXPECT-MATCH: cannot implicitly convert
# Claim (3.8): the conversion runs one way, mutable to immutable.


def main():
    var city = String("Kyiv")
    var reader = Pointer(to=city).as_imm()
    var writer: Pointer[String, origin_of(city)] = reader
    print(writer[])
