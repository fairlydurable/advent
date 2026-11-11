# EXPECT-ERROR: calling a String method on a Pointer to a String
# EXPECT-MATCH: value has no attribute 'byte_length'
# Claim: the dot operator never looks through a pointer. Method lookup happens
# on the Pointer type itself.
def main():
    var hostname = String("db-primary")
    var target = Pointer(to=hostname)
    print(target.byte_length())
