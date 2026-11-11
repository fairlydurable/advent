# EXPECT-ERROR: the constructor returns while one field is still uninitialized
# EXPECT-MATCH: self\.longitude' is uninitialized
# Claim: every path out of an `out self` constructor must initialize every field.


struct Waypoint:
    var latitude: Float64
    var longitude: Float64

    def __init__(out self, latitude: Float64):
        self.latitude = latitude


def main():
    _ = Waypoint(37.77)
