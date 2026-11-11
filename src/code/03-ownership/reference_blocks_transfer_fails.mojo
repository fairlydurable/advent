# EXPECT-ERROR: transferring a value out while a pointer to it is still used
# EXPECT-MATCH: use of uninitialized value 'city'
# Claim (3.1): a live Pointer counts as a use of its owner. After `city^`
# the owner holds no value, so the later dereference reads an uninitialized value.


def main():
    var city = String("Lisbon")
    var cursor = Pointer(to=city)
    var moved = city^
    print(cursor[], moved)
