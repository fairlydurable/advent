# Claims (3.2):
# - Copying first gives the call two distinct values, so it compiles.
# - `List.append(names[0])` compiles: the `var` argument receives a copy of the
#   element before `append` gets mutable access to the list.
from std.testing import assert_equal


def append_twice(mut journal: String, entry: String):
    journal += entry
    journal += entry


def main() raises:
    var journal = String("boot;")
    var entry = journal.copy()
    append_twice(journal, entry)
    assert_equal(journal, "boot;boot;boot;")

    var names: List[String] = ["ada", "grace"]
    names.append(names[0])
    assert_equal(names, ["ada", "grace", "ada"])
