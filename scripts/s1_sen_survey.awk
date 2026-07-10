# S1 failure-signature survey of a Nortek .sen file. One streaming pass, O(n).
#
# Usage:  awk -F' +' -v dep=DEP -v ins=INS -v SKIP=360 -f s1_sen_survey.awk file.sen
#
# .sen columns: 1-6 date, 7 errcode, 8 statuscode, 9 battery, 10 sound speed, 11 heading,
#               12 pitch, 13 roll, 14 temperature
#
# The .sen carries no pressure, so there is no in-water flag. A naive max over the whole
# file measures the instrument being carried on deck at deployment and recovery, not the
# seabed: on the known-healthy MOP586_7m that returns max|pitch| = 162.7 deg and 1.88% of
# samples over 30 deg. Everything is therefore computed on the INTERIOR of the record
# (first and last SKIP minutes dropped), and Tref is the interior MEDIAN, not a leading-
# window mean that the on-deck air temperature would poison.
#
# Percentiles come from histograms. A comparison sort would be O(n^2) in awk on ~23000
# samples per file: minutes each, hours across the archive.
#
# Emits one CSV row. Columns, and how to read them:
#   pct_T_implausible  T outside [-2, 40] C            -> thermistor dead
#   pct_T_dev_gt8      |T - Tref| > 8 C                -> thermistor drifting/dead
#   pct_tilt_gt30      |pitch| or |roll| >= 30 deg     -> frame toppled
#   p99_abs_roll       99th pct |roll| in the interior -> a max would catch the deck handling
#   tilt_drift         mean |roll| last 10% - first 10% -> frame progressively falling
#   head_drift         mean heading last 10% - first 10% -> frame rotating
#   c_min / c_max      sound-speed excursion            -> follows the thermistor
#   pct_batt_out       battery outside [10, 16] V       -> sensor-block electrical fault
#
# Signatures (see docs/OUTSTANDING_channel_decoupling.md section 7):
#   sensor block failed  : pct_T_dev_gt8 high, c range wide, batt out, tilt SMALL   -> recoverable
#   frame toppled        : T/c/batt normal, pct_tilt_gt30 > 0 or |tilt_drift| large -> NOT recoverable
#   healthy              : all near zero

function hpct(hist, m, q, lo, w,   i, cum, target) {
    target = q*m; cum = 0
    for (i = 0; i <= 4000; i++) { cum += hist[i]; if (cum >= target) return lo + (i+0.5)*w }
    return lo + 4000*w
}
function absv(x) { return (x<0) ? -x : x }
function bin(x, lo, w, nb,   b) { b = int((x-lo)/w); if (b<0) b=0; if (b>nb) b=nb; return b }

NR%60==1 { n++; T[n]=$14; P[n]=$12; R[n]=$13; H[n]=$11; B[n]=$9; C[n]=$10 }

END {
    # Interior = the middle 80% of the record. A FIXED skip is not enough: the instrument is
    # powered on before deployment and after recovery, and a 6-hour skip still left 167.7 deg
    # of on-deck roll inside the "interior" of the healthy MOP586_7m. Fractional trimming is
    # parameter-light and scales with the record. This is a SCREEN, not a verdict.
    if (n < 600) { exit }
    lo = int(0.10*n) + 1; hi = int(0.90*n); m = 0
    if (hi - lo < 60) { exit }
    for (i=lo; i<=hi; i++) {
        m++
        ti = T[i]; ap = absv(P[i]); ar = absv(R[i])
        HP[bin(ap, 0, 0.1, 4000)]++
        HR[bin(ar, 0, 0.1, 4000)]++
        HT[bin(ti, -10, 0.05, 4000)]++
        if (ti < -2 || ti > 40) timp++
        if (ap >= 30 || ar >= 30) tilt++
        if (m==1) { cmin=C[i]; cmax=C[i] }
        if (C[i]<cmin) cmin=C[i]
        if (C[i]>cmax) cmax=C[i]
        if (B[i]<10 || B[i]>16) bo++
    }
    Tref = hpct(HT, m, 0.50, -10, 0.05)
    for (i=lo; i<=hi; i++) { d = absv(T[i]-Tref); if (d>8) tdev++ }

    # Drift between the 2nd-3rd decile and the 8th-9th decile of the FULL record: both windows
    # sit well inside, so neither touches deployment or recovery handling.
    a0 = int(0.20*n)+1; a1 = int(0.30*n)
    b0 = int(0.80*n)+1; b1 = int(0.90*n)
    r0=0; h0=0; ka=0
    for (i=a0; i<=a1; i++) { r0 += absv(R[i]); h0 += H[i]; ka++ }
    r1=0; h1=0; kb=0
    for (i=b0; i<=b1; i++) { r1 += absv(R[i]); h1 += H[i]; kb++ }
    tilt_drift = (ka>0 && kb>0) ? r1/kb - r0/ka : 0
    head_drift = (ka>0 && kb>0) ? h1/kb - h0/ka : 0

    printf "%s,%s,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%.2f,%.1f,%.1f,%.2f\n", \
      dep, ins, m, 100*timp/m, 100*tdev/m, Tref, 100*tilt/m, \
      hpct(HP,m,0.95,0,0.1), hpct(HR,m,0.95,0,0.1), hpct(HR,m,0.99,0,0.1), head_drift, 100*bo/m, cmin, cmax, tilt_drift
}
