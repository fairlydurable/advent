# Claim: an opaque foreign type maps to a fieldless struct that Mojo code
# never constructs; values only ever exist behind a `Pointer` that foreign
# code hands out.
# Claim: `Optional[Pointer[...]]` has the size of a bare pointer, so it
# models a nullable C return with no extra tag.
# Claim: one foreign symbol has one signature across the whole program.
# The standard library already declares `fclose` with an
# `Optional[Pointer[NoneType, ...]]` argument, so this code converts its
# handle to that exact type before the call.
from std.ffi import external_call
from std.sys import size_of
from std.testing import assert_equal


struct CFile:
    pass


comptime FileHandle = Pointer[CFile, MutUntrackedOrigin]
comptime StdioFile = Optional[Pointer[NoneType, MutUntrackedOrigin]]


def main() raises:
    assert_equal(size_of[CFile](), 0)
    assert_equal(size_of[Optional[FileHandle]](), size_of[FileHandle]())

    var maybe_file = external_call["tmpfile", Optional[FileHandle]]()
    if not maybe_file:
        raise Error("tmpfile() returned NULL")
    var handle = maybe_file.value()

    _ = external_call["fputc", Int32](Int32(ord("M")), handle)
    external_call["rewind", NoneType](handle)
    var first_byte = external_call["fgetc", Int32](handle)

    var as_stdio: StdioFile = handle.unsafe_bitcast[NoneType]()
    var closed = external_call["fclose", Int32](as_stdio)

    assert_equal(first_byte, Int32(ord("M")))
    assert_equal(closed, 0)
