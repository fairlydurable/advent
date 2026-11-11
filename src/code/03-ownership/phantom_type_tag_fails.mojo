# EXPECT-ERROR: an Id tagged for invoices passed where the function requires a customer Id
# EXPECT-MATCH: cannot be converted from 'Id\[Invoice\]' to 'Id\[Customer\]'
# Claim (3.10): an unused type parameter still distinguishes types.


struct Customer:
    pass


struct Invoice:
    pass


@fieldwise_init
struct Id[Kind: AnyType](ImplicitlyCopyable):
    var value: Int


def load_customer(id: Id[Customer]) -> String:
    return "customer-" + String(id.value)


def main():
    var invoice_id = Id[Invoice](4021)
    print(load_customer(invoice_id))
