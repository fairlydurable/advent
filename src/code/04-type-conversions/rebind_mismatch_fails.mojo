# EXPECT-ERROR: rebinding between types that differ after instantiation
# EXPECT-MATCH: rebind input type .* does not match result type
# Claim: rebind is not a reinterpret cast. If the types still differ once
# parameters resolve, compilation fails.
def main():
    var lanes = SIMD[DType.int32, 4](10, 20, 30, 40)
    var pair = rebind[SIMD[DType.int32, 2]](lanes)
    print(pair)
