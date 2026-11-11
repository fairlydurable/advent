#!/bin/bash
# Runs every sample under src/code/ and checks it against its contract.
#
# Contract, read from each file's header comments:
#   (no marker)               must compile, run, and exit 0
#   # EXPECT-ERROR: <gist>    must FAIL to compile
#   # EXPECT-MATCH: <regex>   (with EXPECT-ERROR) compiler output must match
#                             the extended regex, so it fails for the stated reason
#   # EXPECT-EXIT: nonzero    must compile, then exit nonzero at run time
#
# Usage: MOJO=/path/to/mojo ./run_samples.sh [src/code/subdir ...]
# MOJO defaults to `mojo` on PATH. Sample paths are passed as absolute paths.

MOJO=${MOJO:-mojo}
ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=("$ROOT/src/code")

pass=0; fail=0; failed=()
while IFS= read -r file; do
  out=$("$MOJO" run "$file" 2>&1); status=$?
  if grep -q '^# EXPECT-ERROR:' "$file"; then
    regex=$(sed -n 's/^# EXPECT-MATCH: //p' "$file" | head -1)
    if [ $status -ne 0 ] && echo "$out" | grep -q 'error:' && \
       { [ -z "$regex" ] || echo "$out" | grep -Eq "$regex"; }; then
      ok=1; else ok=0; fi
  elif grep -q '^# EXPECT-EXIT: nonzero' "$file"; then
    # `mojo run` reports a crashed program as its own error; only a
    # source-located error means the sample failed to compile.
    if [ $status -ne 0 ] && ! echo "$out" | grep -Eq '\.mojo:[0-9]+:[0-9]+: error:'; then ok=1; else ok=0; fi
  else
    [ $status -eq 0 ] && ok=1 || ok=0
  fi
  if [ $ok -eq 1 ]; then pass=$((pass+1)); else
    fail=$((fail+1)); failed+=("$file")
    echo "FAIL: ${file#$ROOT/}"; echo "$out" | grep -v 'Crashpad\|libAsyncRTMojoBindings' | head -15
  fi
done < <(for t in "${TARGETS[@]}"; do find "$(cd "$t" && pwd)" -name '*.mojo'; done | sort)

echo "passed: $pass  failed: $fail"
[ $fail -eq 0 ]
