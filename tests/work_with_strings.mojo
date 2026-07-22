# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #
def main():
    print("STRING ASSIGNMENT")
    var string: String = "  Day 1: 20.5C, Partly Cloudy  "
    print(t"string: '{string}'")

    print("\nTSTRING CHECKPOINT")
    # TString construction with interpolation
    var t = t"5 plus 5 is {5 + 5}"
    var math = "Correct: " + String(t)
    print(math)  # Correct: 5 plus 5 is 10

    print("\nSTRING LENGTH")
    var length = string.byte_length()
    print(t"{string} length: {length}")  # 31

    print("\nSTRING ITERATION")
    print([String(t"'{slice}'") for slice in string.codepoint_slices()])
    # [' ', ' ', 'D', 'a', 'y', ' ', '1', ':', ' ', '2', '0', '.', '5',
    #  'C', ',', ' ', 'P', 'a', 'r', 't', 'l', 'y', ' ', 'C', 'l', 'o',
    #  'u', 'd', 'y', ' ', ' ']

    print("\nJOINING STRING SLICES")
    var joined = "".join([slice for slice in string.codepoint_slices()])
    print(t"'{joined}'")  #  '  Day 1: 20.5C, Partly Cloudy  '

    joined = "".join(
        [slice for slice in string.codepoint_slices() if " " not in slice]
    )
    print(t"'{joined}'")  #  'Day1:20.5C,PartlyCloudy'

    print("\nJOINING CHECKPOINT")
    var hello: String = "Hello"
    joined = ", ".join([slice for slice in hello.codepoint_slices()])
    print(t"'{joined}'")  # 'H, e, l, l, o'

    print("\nSTRING REVERSAL")
    var s: String = ""

    # construct and reverse the non-inclusive range
    for index in reversed(range(length)):
        s = s + String(string[byte=index])
    print(t"Reversed bytes: '{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '

    # use the reversed iterator
    s = ""
    for slice in string.codepoint_slices_reversed():
        s += String(slice)
    print(t"'{s}'")  # '  yduolC yltraP ,C5.02 :1 yaD '

    print("\nSTRING INDEXING")
    print(t"byte prefix:     '{string[byte=:5]}'")  # '  Day'
    print(t"byte suffix:     '{string[byte=length - 5:]}'")  # 'udy '
    print(t"byte substring:  '{string[byte=2:10]}'")  # 'Day 1: 2'

    print("\nSEARCH AND CHECK")
    # Contains
    print(t"contains 'Day':       {'Day' in string}")  # True

    # Position
    print(t"position of ':':      {string.find(':')}")  # 7
    print(t"position of '!':      {string.find('!')}")  # -1, not found

    # Start and end
    print(t"starts with '  Day':  {string.startswith('  Day')}")  # True
    print(t"ends with 'Cloudy  ': {string.endswith('Cloudy  ')}")  # True

    print("\nTESTING SEARCHES")
    if string.find("!"):
        print("-1 is truthy")  # This prints
    else:
        print("You'd expect to be here, but you're not")

    if "!" in string:
        print("Found")
    else:
        print("Not found")  # This prints

    print("\nSTRING TRUTHINESS")
    if "":
        print("Won't be printed")
    elif "🔥":
        print("This is printed")

    print("\nTRIMMING STRINGS")
    var cleaned = string.strip()
    print(t"cleaned: '{cleaned}', bytes: {cleaned.byte_length()}")

    print("\nTRIMMING TRY THIS")
    var test = "**🔥Fooxx"
    print(t"'{test.strip("x*🔥")}'")  # 'Foo'

    test = "\n\n\t Hi\n \n"
    print(t"'{test.strip()}'")  # 'Hi'

    print("\nSUBSTITUTIONS")
    var standardized = cleaned.replace("Partly Cloudy", "Cloudy")
    var no_units = standardized.replace("C", "")
    print(standardized)
    print(no_units)  # loudy! Maybe not a great idea

    print("\nSPLITTING STRINGS")
    var parts = cleaned.split(", ")
    print(t"split on ', ': {parts}")  # [Day 1: 20.5C, Partly Cloudy]
    print(t"count: {len(parts)}")  # 2

    print("\nCHANGING CASE")
    print(parts[1].lower())  # partly cloudy
    print(parts[1].upper())  # PARTLY CLOUDY
    print(t"'cloudy' matches: {'cloudy' in cleaned.lower()}")  # True
