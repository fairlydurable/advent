def extract_ints(text: String) raises -> List[Int]:
    var nums = List[Int]()
    var cur = String("")
    for i in range(text.byte_length()):
        var c = String(text[byte=i])
        if c >= "0" and c <= "9":  # an ASCII digit
            cur += c  # extend the current run
        elif cur:  # a run just ended
            nums.append(Int(cur))
            cur = String("")
    if cur:  # a run at the very end
        nums.append(Int(cur))
    return nums^


def main() raises:
    print("TEST ADJACENT LITERALS")
    var x = "Hello, World"
    print(x)  # Hello, World

    print("START OF CONTENT")

    var line: String = (
        "Station 3:\n"
        "  Readings per day this week (M-F): 2, 6, 3, 4, and 5.\n"
        "  (20 readings total)."
    )
    print(line)
    var found = extract_ints(line)
    print(t"found: {found}")  # [3, 2, 6, 3, 4, 5, 20]

    var counts = List[Int]()
    for i in range(1, len(found) - 1):  # skip station id and total
        counts.append(found[i])
    print(t"daily counts: {counts}")  # [2, 6, 3, 4, 5]

    var running_count = 0
    for c in counts:
        running_count += c
    var stated = found[len(found) - 1]
    print(t"sum: {running_count}, stated total: {stated}")
    print(t"match: {running_count == stated}")  # True

    var entry: String = "Station 3, Monday, Reading 1: 22.1 C"
    var fields = entry.split(": ")
    var tail = fields[len(fields) - 1]  # "22.1 C"
    var reading = Float64(String(tail).replace("C", "").strip())
    print(t"reading: {reading}")  # 22.1
