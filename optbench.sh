#!/bin/bash
#
# optbench.sh - measure the effect of the primality-test optimisations.
#
# Runs the three is_prime variants over a range of n and writes
# optimisation.csv:
#
#   n,version,label,time_seconds,primes_found
#
# Version 1 (naive, trial division to k-1) costs O(k) divisions per prime
# instead of O(sqrt(k)), so it is hundreds of times slower and dominates the
# total runtime here - expect roughly two minutes overall.
#
# Build first:
#   gcc -O2 -Wall -o optbench optbench.c -lm
#
set -u

OUT="optimisation.csv"
REPS=3
N_VALUES=(10000 30000 100000 300000 1000000)

if [ ! -x ./optbench ]; then
    echo "Error: ./optbench missing. Build it with:" >&2
    echo "  gcc -O2 -Wall -o optbench optbench.c -lm" >&2
    exit 1
fi

echo "n,version,label,time_seconds,primes_found" > "$OUT"

for n in "${N_VALUES[@]}"; do
    for v in 1 2 3; do
        for rep in $(seq 1 "$REPS"); do
            line=$(./optbench "$n" "$v")
            label=$(printf '%s\n' "$line" | sed -n 's/.*(\([a-z+]*\)).*/\1/p')
            t=$(printf '%s\n' "$line" | sed -n 's/.*time taken = \([0-9.]*\) seconds.*/\1/p')
            p=$(printf '%s\n' "$line" | sed -n 's/.*primes found = \([0-9]*\).*/\1/p')
            echo "$n,$v,$label,$t,$p" >> "$OUT"
            printf '  n=%-8s v%s %-9s %ss\n' "$n" "$v" "$label" "$t" >&2
        done
    done
done

echo "" >&2
echo "Raw data in $OUT" >&2
echo "" >&2

# --- summary: best-of-N per (n, version), plus the improvement factor ----
awk -F, 'NR == 1 { next }
{ k = $1 SUBSEP $2; if (!(k in m) || $4 + 0 < m[k]) m[k] = $4 + 0
  ns[$1] = 1; primes[$1 SUBSEP $5] = 1 }
END {
    printf "%-10s %12s %12s %12s %10s %10s\n",
           "n", "v1 naive", "v2 sqrt", "v3 sqrt+odd", "v1/v3", "v2/v3"
    c = 0
    for (n in ns) order[c++] = n + 0
    for (i = 0; i < c; i++)
        for (j = i + 1; j < c; j++)
            if (order[j] < order[i]) { t = order[i]; order[i] = order[j]; order[j] = t }
    for (i = 0; i < c; i++) {
        n = order[i]
        a = m[n SUBSEP 1]; b = m[n SUBSEP 2]; d = m[n SUBSEP 3]
        printf "%-10s %12.6f %12.6f %12.6f %9.1fx %9.2fx\n", n, a, b, d, a/d, b/d
    }
}' "$OUT" >&2

echo "" >&2
echo "Correctness check:" >&2
awk -F, 'NR > 1 { seen[$1 "," $5] = 1 }
END {
    for (k in seen) { split(k, a, ","); d[a[1]]++ }
    bad = 0
    for (n in d) if (d[n] != 1) { print "  MISMATCH at n=" n; bad = 1 }
    if (!bad) print "  OK - all three versions find the same primes at every n."
}' "$OUT" >&2
