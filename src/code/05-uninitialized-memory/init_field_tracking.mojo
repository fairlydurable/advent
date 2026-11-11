# Claim: inside __init__, the compiler tracks each field separately, so you
# can read a field you already initialized before the others are set.
from std.testing import assert_equal


struct Endpoint(Movable):
    var host: String
    var url: String
    var port: Int

    def __init__(out self, host: String, port: Int):
        self.host = host
        self.url = "https://" + self.host  # host is initialized, so this reads fine
        self.port = port


def main() raises:
    var api = Endpoint("api.internal", 8443)
    assert_equal(api.url, "https://api.internal")
    assert_equal(api.port, 8443)
