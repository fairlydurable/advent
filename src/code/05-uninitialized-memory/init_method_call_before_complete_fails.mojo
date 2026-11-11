# EXPECT-ERROR: calling a method on self before every field is initialized
# EXPECT-MATCH: uninitialized value 'self.port'
# Claim: a method call needs the whole `self`, so it waits until every field
# holds a value.
struct Endpoint(Movable):
    var host: String
    var port: Int

    def __init__(out self, host: String, port: Int):
        self.host = host
        self.log_target()
        self.port = port

    def log_target(self):
        print(self.host, self.port)


def main():
    _ = Endpoint("api.internal", 8443)
