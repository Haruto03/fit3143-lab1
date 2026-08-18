#!/bin/bash
#
# summarize.sh - Turn results.csv into speedup.csv, ready to graph.
#
# Uses the BEST (minimum) time of the repetitions for each configuration.
# Thread scheduling makes the parallel runs vary by up to ~20% run to run,
# so the mean is noticeably noisier than the minimum; best-of-N is the
# standard way to report this kind of measurement. The mean and the spread
# are carried through as extra columns so the variability can still be shown.
#
#   speedup = serial time / parallel time, both at the same n
#
# Usage:
#   ./summarize.sh [results.csv]
#
set -u

IN="${1:-results.csv}"
OUT="speedup.csv"

if [ ! -f "$IN" ]; then
    echo "Error: $IN not found. Run ./benchmark.sh first." >&2
    exit 1
fi

awk -F, '
NR == 1 { next }
{
    key = $1 SUBSEP $3 SUBSEP $4 SUBSEP $2
    if (!(key in tmin) || $6 + 0 < tmin[key]) tmin[key] = $6 + 0
    if (!(key in tmax) || $6 + 0 > tmax[key]) tmax[key] = $6 + 0
    tsum[key] += $6; tcnt[key]++
    if ($2 != "task1") cfg[$1 SUBSEP $3 SUBSEP $4] = $1 "," $3 "," $4
}
END {
    print "experiment,n,threads,serial_s,pthread_s,openmp_s,speedup_pthread,speedup_openmp,pthread_mean_s,openmp_mean_s,pthread_spread_pct,openmp_spread_pct"
    for (c in cfg) {
        split(cfg[c], f, ",")
        e = f[1]; n = f[2]; t = f[3]
        sk = e SUBSEP n SUBSEP 1 SUBSEP "task1"
        ak = e SUBSEP n SUBSEP t SUBSEP "task2"
        bk = e SUBSEP n SUBSEP t SUBSEP "task3"

        sv = (sk in tmin) ? tmin[sk] : 0
        av = (ak in tmin) ? tmin[ak] : 0
        bv = (bk in tmin) ? tmin[bk] : 0
        am = (ak in tcnt) ? tsum[ak] / tcnt[ak] : 0
        bm = (bk in tcnt) ? tsum[bk] / tcnt[bk] : 0
        asp = (av > 0) ? (tmax[ak] - av) / av * 100 : 0
        bsp = (bv > 0) ? (tmax[bk] - bv) / bv * 100 : 0

        printf "%s,%s,%s,%.6f,%.6f,%.6f,%.4f,%.4f,%.6f,%.6f,%.1f,%.1f\n",
               e, n, t, sv, av, bv,
               (av > 0 ? sv / av : 0), (bv > 0 ? sv / bv : 0),
               am, bm, asp, bsp
    }
}' "$IN" | { read -r header; echo "$header"; sort -t, -k1,1 -k2,2n -k3,3n; } > "$OUT"

echo "Wrote $OUT"
echo ""
cut -d, -f1-8 "$OUT" | column -s, -t
