#!/bin/bash
#
# verify.sh - pre-submission checks for task1.c, task2.c and task3.c.
#
# Builds all three with warnings turned up, then checks correctness:
# edge cases, agreement between the three programs, and stability of the
# parallel results across thread counts.
#
# Usage:  bash verify.sh
#
set -u
fail=0

section() { printf '\n=== %s ===\n' "$1"; }
ok()      { printf '  [ OK ]   %s\n' "$1"; }
bad()     { printf '  [FAIL]   %s\n' "$1"; fail=1; }

section "1. Build with -Wall -Wextra"
for spec in "task1:-lm" "task2:-pthread -lm" "task3:-fopenmp -lm"; do
    prog=${spec%%:*}
    flags=${spec#*:}
    out=$(gcc -O2 -Wall -Wextra -o "$prog" "$prog.c" $flags 2>&1)
    if [ -n "$out" ]; then
        bad "$prog.c produced compiler diagnostics:"
        printf '%s\n' "$out" | sed 's/^/           /'
    else
        ok "$prog.c compiled with no warnings"
    fi
done
[ "$fail" -eq 1 ] && { echo; echo "Build problems - stopping."; exit 1; }

section "2. Edge cases (must not crash or print nonsense)"
for args in "1" "2" "3" "4" "10"; do
    r1=$(./task1 $args | tail -1)
    r2=$(./task2 $args 4 | tail -1)
    r3=$(./task3 $args 4 | tail -1)
    c1=$(printf '%s' "$r1" | sed -n 's/.*primes found = \([0-9]*\).*/\1/p')
    c2=$(printf '%s' "$r2" | sed -n 's/.*primes found = \([0-9]*\).*/\1/p')
    c3=$(printf '%s' "$r3" | sed -n 's/.*primes found = \([0-9]*\).*/\1/p')
    if [ "$args" = "1" ]; then
        ok "n=1 handled (no primes below 2)"
    elif [ "$c1" = "$c2" ] && [ "$c1" = "$c3" ]; then
        ok "n=$args -> all three report $c1 prime(s)"
    else
        bad "n=$args -> task1=$c1 task2=$c2 task3=$c3 (disagree)"
    fi
done

section "3. More threads than work (num_threads > n)"
for t in 1 100; do
    c2=$(./task2 5 $t | tail -1 | sed -n 's/.*primes found = \([0-9]*\).*/\1/p')
    c3=$(./task3 5 $t | tail -1 | sed -n 's/.*primes found = \([0-9]*\).*/\1/p')
    if [ "$c2" = "2" ] && [ "$c3" = "2" ]; then
        ok "n=5, $t threads -> both find 2 primes (2, 3)"
    else
        bad "n=5, $t threads -> task2=$c2 task3=$c3 (expected 2)"
    fi
done

section "4. Small-n output goes to stdout, large-n to a file"
if ./task1 30 | grep -q "2, 3, 5, 7"; then
    ok "n=30 prints the sorted list to stdout"
else
    bad "n=30 did not print the expected list to stdout"
fi
rm -f primes_output.txt
./task1 1000 > /dev/null
if [ -f primes_output.txt ]; then
    ok "n=1000 wrote primes_output.txt"
else
    bad "n=1000 did not create primes_output.txt"
fi

section "5. Parallel output matches serial, across thread counts"
N=1000000
./task1 $N > /dev/null
for t in 1 2 3 4 5 7 8 16; do
    ./task2 $N $t > /dev/null
    ./task3 $N $t > /dev/null
    d2=$(diff -q primes_output.txt primes_output_parallel.txt > /dev/null 2>&1 && echo same || echo differ)
    d3=$(diff -q primes_output.txt primes_output_openmp.txt   > /dev/null 2>&1 && echo same || echo differ)
    if [ "$d2" = "same" ] && [ "$d3" = "same" ]; then
        ok "$t thread(s): task2 and task3 byte-identical to task1"
    else
        bad "$t thread(s): task2=$d2 task3=$d3 versus task1"
    fi
done

section "6. Sorted ascending and all genuinely prime"
python3 - <<'PY' || true
import sys
try:
    with open('primes_output.txt') as f:
        f.readline()                       # header
        v = [int(x) for x in f if x.strip()]
except FileNotFoundError:
    print('  [FAIL]   primes_output.txt missing'); sys.exit(1)

if v != sorted(v):
    print('  [FAIL]   output is not in ascending order'); sys.exit(1)
print('  [ OK ]   %d values, strictly ascending' % len(v))

limit = 200000
sieve = bytearray([1]) * limit
sieve[0] = sieve[1] = 0
for i in range(2, int(limit ** 0.5) + 1):
    if sieve[i]:
        sieve[i*i::i] = bytearray(len(sieve[i*i::i]))
expected = [i for i in range(limit) if sieve[i]]
got = [x for x in v if x < limit]
print('  [ OK ]   matches an independent sieve below %d' % limit
      if got == expected else
      '  [FAIL]   disagrees with an independent sieve below %d' % limit)
PY

section "Result"
if [ "$fail" -eq 0 ]; then
    echo "  All checks passed."
else
    echo "  One or more checks FAILED - see above."
fi
exit "$fail"
