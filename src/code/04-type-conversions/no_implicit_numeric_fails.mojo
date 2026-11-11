# EXPECT-ERROR: an Int binding does not convert implicitly to Float64
# EXPECT-MATCH: cannot implicitly convert 'Int' value to 'Float64'
# Claim: literals adapt, but values of one numeric type never convert to
# another without an explicit constructor call such as Float64(count).
def main():
    var count = 7
    var ratio: Float64 = count
    print(ratio)
