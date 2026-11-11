# EXPECT-ERROR: a pointer can't outlive a transfer of the value it points to
# EXPECT-MATCH: use of uninitialized value 'station'
# Claim: once `station^` moves the value out, any pointer into the old
# binding is unusable, and the compiler reports the read.
def main():
    var station = String("north-ridge")
    var label = Pointer(to=station)
    var archived = station^
    print(label[], archived)
