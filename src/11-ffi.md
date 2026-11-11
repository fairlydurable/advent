# 11. FFI

<!-- Compiler verified: 2026-11-11, Mojo 1.3.0.dev0 (repo main c3da0ac4bbf) -->
<!-- Last updated: 2026-11-11 -->
<!-- The 11.10 shared-library build and C host ran on Mojo 1.2.0 (2016d0cd); the repo build lacks the runtime library needed to link one. -->
<!-- VERIFIED: Mojo/stdlib/std/ffi/__init__.mojo, Mojo/stdlib/std/ffi/cstring.mojo, Mojo/stdlib/std/sys/_libc.mojo, Mojo/stdlib/std/collections/string/string.mojo, Mojo/stdlib/std/memory/maybe_uninit.mojo, Mojo/stdlib/std/memory/alloc.mojo, Mojo/stdlib/std/memory/pointer.mojo -->

Call C, let C call you, and keep ownership straight across a boundary that no type checker can see past.

*Rustonomicon counterpart: FFI.*

A foreign call leaves everything the compiler knows behind. C has no origins,
no destructors, and no notion of who owns a pointer. On the Mojo side of the
call you state those facts in types: which origin a returned pointer borrows
from, whether a pointer may be null, which allocator owns a block. The
compiler then checks the Mojo side against what you stated. It can't check
that you stated the truth.

Every sample in this chapter calls libc, libm, libz, or pthreads, so it runs
without building a C library first. The one exception, a C program calling
Mojo, appears as a listing with its build commands.

## 11.1 Calling C

`external_call["symbol", ReturnType](args...)` calls a C function that the
process already links. The standard C types live in `std.ffi`: `c_int` is
`Int32`, `c_long` follows the platform, `c_size_t` is `UInt`, and `c_char`
is signed or unsigned to match the platform's `char`.

```mojo
# Claims:
# - external_call["name", ReturnType](args...) calls a C function that the
#   process already links (libc here), with no binding declarations.
# - C's int maps to c_int (Int32) and size_t to c_size_t (UInt).
# - A string literal passes to a const char* parameter through
#   as_c_string_span(), which guarantees a terminating zero byte.
# - A struct C returns by value must be RegisterPassable and must declare its
#   fields in C order.

from std.ffi import c_int, c_size_t, external_call
from std.testing import assert_equal


@fieldwise_init
struct DivT(RegisterPassable):  # C's div_t
    var quot: c_int
    var rem: c_int


def main() raises:
    # int abs(int);
    assert_equal(external_call["abs", c_int](c_int(-273)), 273)

    # size_t strlen(const char *);
    var length = external_call["strlen", c_size_t]("thermocouple".as_c_string_span())
    assert_equal(length, 12)

    # div_t div(int numerator, int denominator);
    var minutes = external_call["div", DivT](c_int(437), c_int(60))
    assert_equal(minutes.quot, 7)
    assert_equal(minutes.rem, 17)
```

[code/11-ffi/calling_c.mojo](code/11-ffi/calling_c.mojo)

A struct that C returns by value must be `RegisterPassable`, and its fields
must appear in C's order with C's types. Nothing checks the match: declare
`DivT` with its fields swapped and the call still compiles and returns the
remainder in `quot`.

`external_call` declares the C symbol at each call site, with the types at
that site. All the declarations of one symbol in a program must agree,
including declarations inside the standard library. `Pointer` and
`Optional[Pointer]` count as different types even though they share a layout:

```mojo
# EXPECT-ERROR: two external_call sites that give one C symbol different Mojo types conflict
# EXPECT-MATCH: existing function with conflicting signature
# Claim: external_call declares the C symbol at each call site, and every
# declaration of one symbol in the program must agree, including ones inside
# the standard library. Pointer and Optional[Pointer] count as different
# types even though they share a layout.

from std.ffi import c_int, c_long, external_call


def main():
    var offset = external_call["abs", c_int](c_int(-40))
    var wide = external_call["abs", c_long](c_long(-40))
    print(offset, wide)
```

[code/11-ffi/signature_conflict_fails.mojo](code/11-ffi/signature_conflict_fails.mojo)

The same rule bites when you declare a libc function that the standard
library also wraps. `std.sys._libc` declares `fopen` and `fclose` with a
`FILE` handle of type `Optional[Pointer[NoneType, MutUntrackedOrigin]]`, so a
program that declares `fclose` with a plain `Pointer` fails to compile as
soon as anything pulls in the standard library's version. Spell such handles
the way the standard library does, as the samples in 11.7 do.

C variadic functions need `num_fixed_args`. On arm64 macOS, the ABI passes
variadic arguments on the stack and fixed ones in registers, so the caller
has to know where the fixed list ends. Leaving it out compiles and produces
undefined behavior on that platform. Section 11.4 calls `snprintf` with it.

## 11.2 Loading libraries

`OwnedDLHandle(path)` opens a library with `dlopen` and closes it with
`dlclose` in its destructor. `get_function[ReturnType](name)` looks up a
symbol and returns a callable:

```mojo
# Claims:
# - OwnedDLHandle(path) dlopens a library and dlcloses it in its destructor.
# - get_function[ReturnType](name) returns a callable that borrows the
#   handle, so the library cannot close between lookup and call.
# - A missing symbol raises an Error instead of aborting.
# - OwnedDLHandle() with no path opens the symbols already in the process.

from std.ffi import OwnedDLHandle, c_double, c_size_t
from std.sys.info import platform_map
from std.testing import assert_equal, assert_false, assert_raises, assert_true

comptime LIBM = platform_map["libm", linux="libm.so.6", macos="libm.dylib"]()


def main() raises:
    var libm = OwnedDLHandle(LIBM)
    assert_true(libm.check_symbol("hypot"))
    var hypot = libm.get_function[c_double]("hypot")
    assert_equal(hypot(c_double(3.0), c_double(4.0)), 5.0)

    assert_false(libm.check_symbol("hypotenuse_of_the_week"))
    with assert_raises(contains="symbol not found"):
        _ = libm.get_function[c_double]("hypotenuse_of_the_week")

    var process = OwnedDLHandle()
    var strlen = process.get_function[c_size_t]("strlen")
    assert_equal(strlen("Kelvin".as_c_string_span()), 6)
```

[code/11-ffi/loading_libraries.mojo](code/11-ffi/loading_libraries.mojo)

The callable borrows the handle, so ASAP destruction can't close the library
between the lookup and the call. It does not borrow the handle for the
lifetime of anything the call returns. When a function returns a pointer into
the library's own static data, that pointer stays valid only while the
library stays mapped, and the return type has to say so:

```mojo
# Claims:
# - A pointer that a library returns into its own static data is valid only
#   while the library stays loaded.
# - Typing the result with the handle's origin keeps the handle alive for as
#   long as the pointer lives, with no manual keep-alive.
# - String(unsafe_from_utf8_ptr=) copies the bytes, after which the copy
#   outlives the library.

from std.ffi import OwnedDLHandle, c_char
from std.sys.info import platform_map
from std.testing import assert_true

comptime LIBZ = platform_map["libz", linux="libz.so.1", macos="libz.dylib"]()


def zlib_version() raises -> String:
    var zlib = OwnedDLHandle(LIBZ)
    comptime borrowed_from_zlib = ImmOrigin(origin_of(zlib))
    # const char *zlibVersion(void);  (points into libz itself)
    var version_fn = zlib.get_function[Pointer[c_char, borrowed_from_zlib]](
        "zlibVersion"
    )
    var version = version_fn()
    return String(unsafe_from_utf8_ptr=version)  # copy before zlib closes


def main() raises:
    var version = zlib_version()
    assert_true(version.startswith("1."))
```

[code/11-ffi/library_owned_pointer.mojo](code/11-ffi/library_owned_pointer.mojo)

`Pointer[c_char, ImmOrigin(origin_of(zlib))]` ties the returned pointer to the
handle. The handle stays open while the pointer lives, with no manual
keep-alive, and the copy into a `String` outlives both. Typing the result with
`ImmStaticOrigin` or an untracked origin instead lies about the lifetime. The
compiler then closes the library right after the call, and the first read
through the pointer is undefined behavior. Libraries in the system's shared
cache often stay mapped after `dlclose`, which hides the bug on one machine
and exposes it on the next.

## 11.3 C-compatible layout

Mojo lays out struct fields in declaration order and pads them by C's rules,
so a struct that lists C's fields in C's order has C's size and alignment.
Two types break the correspondence: `SIMD` aligns to its full vector width,
and `Array` aligns to its element.

```mojo
# Claims:
# - Mojo lays struct fields out in declaration order with C's padding rules,
#   so a struct that lists C's fields in C's order matches C's size.
# - SIMD[DType.float32, 4] aligns to 16 bytes, so it does not match C's
#   float[4]; Array[Float32, 4] aligns to 4 and does.
# - @align(16) raises a struct's alignment, like _Alignas(16).
# - UnsafeUnion is as large as its largest member.

from std.ffi import UnsafeUnion, c_char, c_double, c_int
from std.sys import align_of, size_of
from std.testing import assert_equal


@fieldwise_init
struct Reading(RegisterPassable):  # struct { char unit; double value; }
    var unit: c_char
    var value: c_double


@fieldwise_init
struct PackedFirst(RegisterPassable):  # struct { double value; char unit; }
    var value: c_double
    var unit: c_char


struct SimdVector:  # NOT struct { uint8_t tag; float v[4]; }
    var tag: UInt8
    var v: SIMD[DType.float32, 4]


struct ArrayVector:  # struct { uint8_t tag; float v[4]; }
    var tag: UInt8
    var v: Array[Float32, 4]


@align(16)
@fieldwise_init
struct CacheTag(RegisterPassable):  # struct { _Alignas(16) int id; }
    var id: c_int


def main() raises:
    assert_equal(size_of[Reading](), 16)  # 1 byte, 7 padding, 8 bytes
    assert_equal(size_of[PackedFirst](), 16)  # trailing padding to align 8
    assert_equal(size_of[SimdVector](), 32)
    assert_equal(size_of[ArrayVector](), 20)
    assert_equal(align_of[CacheTag](), 16)
    assert_equal(size_of[CacheTag](), 16)
    assert_equal(size_of[UnsafeUnion[c_int, c_double]](), 8)
```

[code/11-ffi/c_layout.mojo](code/11-ffi/c_layout.mojo)

For a C array field such as `float v[4]`, use `Array[Float32, 4]`.
`SIMD[DType.float32, 4]` moves the field to a 16-byte boundary and grows the
struct from 20 bytes to 32, and every field after it lands at the wrong
offset. `@align(16)` raises a struct's alignment the way `_Alignas(16)` does.
`UnsafeUnion` reserves room for its largest member and tracks nothing about
which member it holds. Mojo has no bitfields and no packed layout, so a C
struct that uses either needs manual byte access.

## 11.4 Strings

C strings end at a zero byte. `String.as_c_string_span()` returns a
`CStringSpan` that guarantees one, appending it to the string's buffer if
needed. That's why the method takes `mut self`: it may reallocate the string
to make room. It therefore needs a named `String`, not a temporary, and the
span's origin is the string, which keeps the string alive while C reads it.
String literals already end in a zero byte.

```mojo
# Claims:
# - as_c_string_span() returns a CStringSpan whose origin is the String, so
#   the String stays alive while C reads it.
# - strlen() counts bytes up to the first zero; byte_length() counts the
#   String's bytes. They differ when the String contains a zero byte.
# - String(unsafe_from_utf8_ptr=) copies up to the first zero byte.
# - snprintf is variadic: num_fixed_args tells external_call how many
#   leading arguments are fixed, which matters on ABIs that pass variadic
#   arguments differently (arm64 macOS passes them on the stack).

from std.ffi import c_char, c_double, c_int, c_size_t, external_call
from std.testing import assert_equal


def main() raises:
    var sensor = String("probe-7")
    var span = sensor.as_c_string_span()
    assert_equal(external_call["strlen", c_size_t](span), 7)

    var with_nul = String("probe\0seven")
    assert_equal(with_nul.byte_length(), 11)
    assert_equal(external_call["strlen", c_size_t](with_nul.as_c_string_span()), 5)

    var buffer = Array[c_char, 64](fill=0)
    # int snprintf(char *buf, size_t size, const char *format, ...);
    var written = external_call["snprintf", c_int, num_fixed_args=3](
        buffer.unsafe_ptr(),
        c_size_t(len(buffer)),
        "%s reads %.1f C".as_c_string_span(),
        sensor.as_c_string_span(),
        c_double(21.5),
    )
    assert_equal(written, 20)
    assert_equal(String(unsafe_from_utf8_ptr=buffer.unsafe_ptr()), "probe-7 reads 21.5 C")
```

[code/11-ffi/c_strings.mojo](code/11-ffi/c_strings.mojo)

Three facts in that sample trip people up:

- `strlen` stops at the first zero byte; `byte_length()` counts every byte
  of the `String`, including interior zeros.
- `String(unsafe_from_utf8_ptr=)` copies bytes up to the first zero. After
  the copy, the C buffer can go away.
- `num_fixed_args=3` marks `buf`, `size`, and `format` as fixed. The two
  arguments after them travel as variadic arguments.

A C buffer that lacks the zero byte makes `strlen` and
`String(unsafe_from_utf8_ptr=)` read past its end, which is undefined
behavior. Size buffers one byte larger than the longest text they hold, and
zero-fill them first, as `Array[c_char, 64](fill=0)` does.

## 11.5 Nullable pointers

`Pointer` can't be null. A C pointer that may be null maps to
`Optional[Pointer[...]]`, which has the same size as a pointer because
`None` uses the null address. That makes `Optional[Pointer]` the type to use
for a nullable argument, for a nullable return, and for a struct field that C
may leave null.

```mojo
# Claims:
# - Pointer cannot be null; Optional[Pointer] models a nullable C pointer.
# - Optional[Pointer] has the same size as a pointer: None is the null
#   address, so it passes to and from C unchanged.
# - Passing None where C expects a pointer passes NULL.
# - A C function that can return NULL gets an Optional return type.

from std.ffi import c_char, external_call
from std.sys import size_of
from std.testing import assert_equal, assert_false, assert_true

comptime time_t = Int64


def main() raises:
    assert_equal(
        size_of[Optional[Pointer[Int64, MutUntrackedOrigin]]](),
        size_of[Pointer[Int64, MutUntrackedOrigin]](),
    )

    # time_t time(time_t *tloc);  tloc may be NULL
    var no_slot: Optional[Pointer[time_t, MutUntrackedOrigin]] = None
    var now = external_call["time", time_t](no_slot)
    assert_true(now > 1_700_000_000)

    # char *getenv(const char *name);  NULL when unset
    var missing = external_call[
        "getenv", Optional[Pointer[c_char, ImmUntrackedOrigin]]
    ]("MOJONOMICON_UNSET_VARIABLE".as_c_string_span())
    assert_false(Bool(missing))

    var path = external_call[
        "getenv", Optional[Pointer[c_char, ImmUntrackedOrigin]]
    ]("PATH".as_c_string_span())
    if path:
        assert_true(String(unsafe_from_utf8_ptr=path.value()).byte_length() > 0)
```

[code/11-ffi/nullable_pointers.mojo](code/11-ffi/nullable_pointers.mojo)

Declaring a return type of plain `Pointer` for a function that can return
NULL compiles. A null result then violates the type's own invariant, which is
undefined behavior, and the program has no way to test for null first,
because the type promised it couldn't happen.

## 11.6 C-style out arguments

A C function that writes its result through a pointer argument takes
`Pointer(to=binding)` of a Mojo value. When the value has no sensible
placeholder, `MaybeUninit[T]` provides storage with `T`'s layout and no
initialization:

```mojo
# Claims:
# - A C-style out argument takes Pointer(to=binding) of a Mojo value.
# - MaybeUninit[T] has T's layout, so C can initialize it through
#   unsafe_ptr() without a placeholder value first.
# - unsafe_assume_init() is the promise that C wrote the value; read it only
#   after checking C's status code.

from std.ffi import c_double, c_int, c_long, external_call
from std.memory import MaybeUninit
from std.sys import size_of
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Timespec(RegisterPassable):
    var tv_sec: Int64  # time_t
    var tv_nsec: c_long


comptime CLOCK_REALTIME = c_int(0)


def main() raises:
    # double frexp(double value, int *exponent);
    var exponent: c_int = 0
    var mantissa = external_call["frexp", c_double](
        c_double(48.0), Pointer(to=exponent)
    )
    assert_equal(mantissa, 0.75)
    assert_equal(exponent, 6)  # 48 = 0.75 * 2**6

    assert_equal(size_of[MaybeUninit[Timespec]](), size_of[Timespec]())
    var slot = MaybeUninit[Timespec]()
    # int clock_gettime(clockid_t clock, struct timespec *tp);
    var status = external_call["clock_gettime", c_int](
        CLOCK_REALTIME, slot.unsafe_ptr()
    )
    assert_equal(status, 0)
    ref now = slot.unsafe_assume_init()  # sound only because status was 0
    assert_true(now.tv_sec > 1_700_000_000)
    assert_true(now.tv_nsec >= 0 and now.tv_nsec < 1_000_000_000)
```

[code/11-ffi/out_arguments.mojo](code/11-ffi/out_arguments.mojo)

`unsafe_assume_init()` is a promise that C wrote a complete `T`. Check the
status code first: on failure, C may have written nothing, and reading the
slot is undefined behavior. `MaybeUninit[Timespec]` needs no cleanup because
`Timespec` has a trivial destructor. For a `T` with a real destructor,
`MaybeUninit[T]` is itself linear: you consume it with
`unsafe_assume_init()` to take the value, `unsafe_deinit()` to destroy it,
or `unsafe_forget()` to discard it.

## 11.7 Callbacks

A Mojo function declared `abi("C")` passes to C as a function pointer. The
classic case is `qsort`, which calls a comparator with two `const void*`
arguments:

```mojo
# Claims:
# - A Mojo function declared abi("C") passes to C as a function pointer.
# - qsort calls the comparator with const void* arguments; the comparator
#   casts them back to the element type it knows they point at.
# - qsort sorts the List's storage in place through unsafe_ptr().

from std.ffi import c_int, c_size_t, external_call
from std.sys import size_of
from std.testing import assert_equal


def by_latency(
    left: ImmOpaquePointer[ImmUntrackedOrigin],
    right: ImmOpaquePointer[ImmUntrackedOrigin],
) abi("C") -> c_int:
    var left_ms = left.unsafe_bitcast[Float64]()[]
    var right_ms = right.unsafe_bitcast[Float64]()[]
    return c_int(-1) if left_ms < right_ms else c_int(left_ms > right_ms)


def main() raises:
    var latencies_ms: List[Float64] = [12.5, 3.25, 48.0, 7.75, 3.0]
    # void qsort(void *base, size_t count, size_t size,
    #            int (*compare)(const void *, const void *));
    external_call["qsort", NoneType](
        latencies_ms.unsafe_ptr(),
        c_size_t(len(latencies_ms)),
        c_size_t(size_of[Float64]()),
        by_latency,
    )
    assert_equal(latencies_ms, [3.0, 3.25, 7.75, 12.5, 48.0])
```

[code/11-ffi/qsort_callback.mojo](code/11-ffi/qsort_callback.mojo)

`external_call` takes its arguments as an untyped pack, so it checks nothing
about a callback. Pass a function without `abi("C")` and the call compiles;
C then calls it with the wrong convention, which is undefined behavior. Name
the C function type with `comptime` and store the callback in it first, and
the compiler checks the convention:

```mojo
# EXPECT-ERROR: a function without abi("C") does not convert to a C function-pointer type
# EXPECT-MATCH: cannot implicitly convert .* value to 'Comparator'
# Claim: external_call takes its arguments as an untyped pack and checks
# nothing about a callback's calling convention. Naming the C function type
# with comptime and storing the callback in it first makes the compiler
# check the ABI.

from std.ffi import c_int

comptime Comparator = def(
    ImmOpaquePointer[ImmUntrackedOrigin], ImmOpaquePointer[ImmUntrackedOrigin]
) thin abi("C") -> c_int


def by_latency(
    left: ImmOpaquePointer[ImmUntrackedOrigin],
    right: ImmOpaquePointer[ImmUntrackedOrigin],
) -> c_int:  # missing abi("C")
    var left_ms = left.unsafe_bitcast[Float64]()[]
    var right_ms = right.unsafe_bitcast[Float64]()[]
    return c_int(-1) if left_ms < right_ms else c_int(left_ms > right_ms)


def main():
    var compare: Comparator = by_latency
    _ = compare
```

[code/11-ffi/callback_abi_fails.mojo](code/11-ffi/callback_abi_fails.mojo)

A C function pointer is one address and carries no environment, so an
`abi("C")` function can't capture:

```mojo
# EXPECT-ERROR: an abi("C") function cannot capture local variables, because a C function pointer has nowhere to carry them
# EXPECT-MATCH: cannot capture variables
# Claim: the compiler rejects a capturing abi("C") function; pass state
# through a void* context argument instead (callback_with_context.mojo).

from std.ffi import c_int


def main():
    var descending = True

    def by_latency(
        left: ImmOpaquePointer[ImmUntrackedOrigin],
        right: ImmOpaquePointer[ImmUntrackedOrigin],
    ) abi("C") {imm descending} -> c_int:
        var left_ms = left.unsafe_bitcast[Float64]()[]
        var right_ms = right.unsafe_bitcast[Float64]()[]
        return c_int(left_ms < right_ms) if descending else c_int(
            left_ms > right_ms
        )

    _ = by_latency
```

[code/11-ffi/capturing_callback_fails.mojo](code/11-ffi/capturing_callback_fails.mojo)

C APIs carry state through a `void*` context argument instead. The callback
casts the context back to the type the caller pointed it at.
`pthread_create` is a real example, and it runs the callback on another
thread:

```mojo
# Claims:
# - An abi("C") function cannot capture, so C APIs pass state through a
#   void* context argument instead.
# - pthread_create hands its void* argument, unchanged, to the start
#   routine on the new thread; the routine casts it back to the type the
#   caller pointed it at.
# - The caller must keep the pointed-to value alive until the callback can
#   no longer run; here pthread_join provides that guarantee.

from std.ffi import c_int, external_call
from std.testing import assert_equal

comptime pthread_t = UInt  # pointer-sized on Linux and macOS
comptime Context = MutOpaquePointer[MutUntrackedOrigin]


struct Job:
    var samples: List[Int]
    var total: Int

    def __init__(out self, var samples: List[Int]):
        self.samples = samples^
        self.total = 0


def sum_samples(context: Context) abi("C") -> Optional[Context]:
    ref job = context.unsafe_bitcast[Job]()[]
    for sample in job.samples:
        job.total += sample
    return None


def main() raises:
    var job = Job([512, 1024, 2048, 4096])
    var thread: pthread_t = 0
    var no_attributes: Optional[Context] = None
    var context = (
        Pointer(to=job).unsafe_bitcast[NoneType]().unsafe_origin_cast[
            MutUntrackedOrigin
        ]()
    )
    # int pthread_create(pthread_t *thread, const pthread_attr_t *attr,
    #                    void *(*start)(void *), void *arg);
    var created = external_call["pthread_create", c_int](
        Pointer(to=thread), no_attributes, sum_samples, context
    )
    assert_equal(created, 0)
    var no_result: Optional[Pointer[Optional[Context], MutUntrackedOrigin]] = None
    # int pthread_join(pthread_t thread, void **result);
    assert_equal(external_call["pthread_join", c_int](thread, no_result), 0)
    assert_equal(job.total, 7680)
```

[code/11-ffi/callback_with_context.mojo](code/11-ffi/callback_with_context.mojo)

The context pointer has an untracked origin, so the compiler no longer links
it to `job`. That moves a lifetime obligation onto you: `job` must stay alive
until the callback can't run anymore. Here `pthread_join` guarantees that the
thread finished, and the read of `job.total` after the join keeps `job` alive
until then. Remove that read and `job` dies at its last tracked use, the line
that builds the context, while the thread may still be writing to it.

A callback can't raise either. C has no way to receive a Mojo error, so the
compiler rejects `raises` on an `abi("C")` function. Convert errors to a
status value before returning:

```mojo
# EXPECT-ERROR: an abi("C") function cannot be marked raises, because C has no way to receive a Mojo error
# EXPECT-MATCH: may not be marked 'raises'
# Claim: the compiler rejects a raising abi("C") function; convert errors to
# a status value inside the callback instead.

from std.ffi import c_int


def parse_channel(text: Int32) abi("C") raises -> c_int:
    if text < 0:
        raise Error("negative channel")
    return text


def main():
    _ = parse_channel
```

[code/11-ffi/raising_callback_fails.mojo](code/11-ffi/raising_callback_fails.mojo)

## 11.8 Ownership across the boundary

Every pointer that crosses the boundary has an owner, and the owner's
allocator must free it. Three rules cover it:

1. Memory that C allocates (`malloc`, `strdup`, `fopen`) goes back through
   the C function that pairs with it (`free`, `fclose`).
2. Memory that Mojo allocates goes back through `dealloc()`.
3. Mixing the two is undefined behavior, even when both allocators happen to
   share an implementation on one platform.

Wrapping a C allocation in a `Deinitable` struct ties the release to Mojo's
destruction, so it happens exactly once, at the wrapper's last use:

```mojo
# Claims:
# - Memory C allocates (strdup, malloc) belongs to C's allocator and goes
#   back through free(), never through dealloc().
# - Wrapping the C pointer in a Deinitable struct ties free() to Mojo's
#   destruction, so the release happens exactly once at the last use.
# - String(unsafe_from_utf8_ptr=) copies, so the Mojo String outlives the
#   C buffer.
# - as_c_string_span() takes `mut self` (it may append the zero byte), so it
#   needs a named String, not a temporary.

from std.ffi import c_char, external_call
from std.memory import ArcPointer
from std.testing import assert_equal


struct CString(Movable):
    """Owns a NUL-terminated string allocated by C's malloc."""

    var _ptr: Pointer[c_char, MutUntrackedOrigin]
    var _frees: ArcPointer[Int]  # counts free() calls for the test

    def __init__(out self, var text: String, frees: ArcPointer[Int]) raises:
        # char *strdup(const char *s);
        var copy = external_call[
            "strdup", Optional[Pointer[c_char, MutUntrackedOrigin]]
        ](text.as_c_string_span())
        if not copy:
            raise Error("strdup failed")
        self._ptr = copy.value()
        self._frees = frees

    def to_string(self) -> String:
        return String(unsafe_from_utf8_ptr=self._ptr)

    def __deinit__(deinit self):
        external_call["free", NoneType](self._ptr)
        self._frees[] += 1


def main() raises:
    var frees = ArcPointer(0)
    var label = CString("rack-12/slot-3", frees)
    var copy = label.to_string()
    assert_equal(frees[], 1)  # `label` died at its last use, above
    assert_equal(copy, "rack-12/slot-3")
```

[code/11-ffi/c_owned_memory.mojo](code/11-ffi/c_owned_memory.mojo)

When the release can fail, a linear wrapper fits better. `fclose` flushes
buffered writes and reports failure, so a file that closes silently in a
destructor can lose data without telling anyone. A `CFile` with no implicit
destructor and a `close()` that returns the status makes every caller decide:

```mojo
# Claims:
# - A C resource whose release can fail (fclose reports write errors) fits a
#   linear type: no implicit destructor, only a named close() that returns
#   the status.
# - The compiler then rejects any path that drops the file without closing
#   it (see linear_c_resource_fails.mojo).

from std.ffi import c_char, c_int, external_call
from std.testing import assert_equal, assert_true

# Spelled exactly as the standard library spells it: every external_call
# to one C symbol in a program must use the same Mojo types.
comptime FILE = Optional[MutOpaquePointer[MutUntrackedOrigin]]


struct CFile(Movable, not Deinitable else "call close() to release a CFile"):
    var _handle: FILE

    def __init__(out self, var path: String, var mode: String) raises:
        # FILE *fopen(const char *path, const char *mode);
        var handle = external_call["fopen", FILE](
            path.as_c_string_span(), mode.as_c_string_span()
        )
        if not handle:
            raise Error("fopen failed")
        self._handle = handle

    def write(self, var line: String) -> Bool:
        # int fputs(const char *s, FILE *stream);
        return external_call["fputs", c_int](
            line.as_c_string_span(), self._handle
        ) >= 0

    def close(deinit self) -> Bool:
        # int fclose(FILE *stream);
        return external_call["fclose", c_int](self._handle) == 0


def main() raises:
    var log = CFile("/tmp/mojonomicon_ffi.log", "w")
    var wrote = log.write("calibration complete\n")
    var closed = log^.close()
    assert_true(wrote)
    assert_true(closed)
    # int remove(const char *path);
    assert_equal(
        external_call["remove", c_int]("/tmp/mojonomicon_ffi.log".as_c_string_span()),
        0,
    )
```

[code/11-ffi/linear_c_resource.mojo](code/11-ffi/linear_c_resource.mojo)

```mojo
# EXPECT-ERROR: a linear C file wrapper dropped without close() is a compile error
# EXPECT-MATCH: abandoned without being explicitly destroyed: call close
# Claim: an early return that forgets close() does not compile.

from std.ffi import c_int, external_call

# Spelled exactly as the standard library spells it: every external_call
# to one C symbol in a program must use the same Mojo types.
comptime FILE = Optional[MutOpaquePointer[MutUntrackedOrigin]]


struct CFile(Movable, not Deinitable else "call close() to release a CFile"):
    var _handle: FILE

    def __init__(out self, var path: String) raises:
        var handle = external_call["fopen", FILE](
            path.as_c_string_span(), "w".as_c_string_span()
        )
        if not handle:
            raise Error("fopen failed")
        self._handle = handle

    def close(deinit self) -> Bool:
        return external_call["fclose", c_int](self._handle) == 0


def log_reading(celsius: Float64) raises:
    var log = CFile("/tmp/mojonomicon_ffi.log")
    if celsius < -273.15:
        return  # forgot log^.close()
    _ = log^.close()


def main() raises:
    log_reading(21.5)
```

[code/11-ffi/linear_c_resource_fails.mojo](code/11-ffi/linear_c_resource_fails.mojo)

Mojo memory lent to C stays owned by its `Allocation`. When a C API keeps a
pointer past the call (a registered buffer, a stored handle), leak the
`Allocation` into a raw pointer for the duration and rebuild it with the
original `Layout` to free it:

```mojo
# Claims:
# - Mojo memory lent to C stays owned by its Allocation: C writes through the
#   pointer, and dealloc() releases it afterward.
# - unsafe_leak() turns an Allocation into a bare pointer that can travel
#   through C as an opaque handle; ThinAllocation plus the original Layout
#   turns it back into something dealloc() accepts.

from std.ffi import c_int, c_size_t, external_call
from std.memory import Layout, ThinAllocation, alloc, dealloc
from std.testing import assert_equal


def main() raises:
    var layout = Layout[UInt8](length=32)
    var frame = alloc(layout)
    # void *memset(void *dest, int byte, size_t count);
    _ = external_call["memset", MutOpaquePointer[MutUntrackedOrigin]](
        frame.unsafe_ptr(), c_int(0x7E), c_size_t(len(frame))
    )
    var last = frame.unsafe_ptr()[unsafe_offset=31]
    dealloc(frame^)
    assert_equal(last, 0x7E)

    # Hand ownership out as a raw handle, as a C API that stores a void*
    # would hold it, then reclaim it.
    var handle = alloc(layout).unsafe_leak()
    handle.write(0x01)
    var reclaimed = ThinAllocation(unsafe_owned_ptr=handle)
    dealloc(reclaimed^.unsafe_with_layout(layout))
```

[code/11-ffi/mojo_owned_memory.mojo](code/11-ffi/mojo_owned_memory.mojo)

## 11.9 errno

C functions report why they failed through `errno`. `get_errno()` reads it
and `set_errno()` writes it:

```mojo
# Claims:
# - C functions report the reason for a failure through errno, which
#   get_errno() reads.
# - Read errno right after the failing call and only when the call's own
#   return value says it failed; a later successful call may change it.
# - set_errno() writes errno, which lets code clear it before a call whose
#   return value cannot signal failure on its own.

from std.ffi import ErrNo, c_int, external_call, get_errno, set_errno
from std.testing import assert_equal, assert_false, assert_true

comptime FILE = Optional[MutOpaquePointer[MutUntrackedOrigin]]


def open_config(var path: String) raises -> FILE:
    # FILE *fopen(const char *path, const char *mode);
    var file = external_call["fopen", FILE](
        path.as_c_string_span(), "r".as_c_string_span()
    )
    if not file:
        raise Error("cannot open ", path, ": ", get_errno())
    return file


def main() raises:
    var missing = external_call["fopen", FILE](
        "/no/such/dir/sensors.conf".as_c_string_span(), "r".as_c_string_span()
    )
    assert_false(Bool(missing))
    assert_true(get_errno() == ErrNo.ENOENT)

    set_errno(ErrNo.SUCCESS)
    assert_true(get_errno() == ErrNo.SUCCESS)

    var failed = False
    try:
        _ = open_config("/no/such/dir/sensors.conf")
    except e:
        failed = True
        assert_true(String(e).startswith("cannot open"))
    assert_true(failed)
```

[code/11-ffi/errno_reporting.mojo](code/11-ffi/errno_reporting.mojo)

Read `errno` only after the function's own return value signals failure, and
read it before any other call. A successful C call may leave `errno` at any
value, and any call in between may change it, including calls hidden inside
other library code.

## 11.10 Exporting Mojo to C

`@export` gives a function an unmangled, externally visible symbol, and
`abi("C")` gives it the C calling convention. Together they make a function
that a C program can call through a plain function pointer:

```mojo
# Claims:
# - @export keeps a function's symbol name unmangled and visible in a
#   shared library built with `mojo build --emit shared-lib`.
# - abi("C") gives the function the C calling convention, so a C host can
#   call it through a plain function pointer.
# - An exported abi("C") function stays an ordinary Mojo function that Mojo
#   code can call directly.
# The C-host round trip appears in the chapter; this sample checks the
# Mojo side.

from std.ffi import c_double
from std.testing import assert_equal


@export
def celsius_to_kelvin(celsius: c_double) abi("C") -> c_double:
    return celsius + 273.15


def main() raises:
    assert_equal(celsius_to_kelvin(-273.15), 0.0)
```

[code/11-ffi/exporting_to_c.mojo](code/11-ffi/exporting_to_c.mojo)

To call it from C, build a shared library and load it:

```sh
mojo build exporting_to_c.mojo --emit shared-lib -o libthermo.dylib
nm -gU libthermo.dylib   # lists _celsius_to_kelvin; non-exported functions don't appear
```

```c
#include <dlfcn.h>
#include <stdio.h>

int main(int argc, char **argv) {
    void *library = dlopen(argv[1], RTLD_NOW);
    double (*to_kelvin)(double) = dlsym(library, "celsius_to_kelvin");
    printf("%.2f\n", to_kelvin(21.5));  /* 294.65 */
    return 0;
}
```

An exported function that uses the Mojo runtime (its thread pool, or
anything built on it) has to call `initialize_runtime()` from `std.runtime`
first, because no Mojo `main()` ran to set it up. An exported function can't
raise, for the same reason a callback can't: catch errors inside it and
return a status the C caller can read.
