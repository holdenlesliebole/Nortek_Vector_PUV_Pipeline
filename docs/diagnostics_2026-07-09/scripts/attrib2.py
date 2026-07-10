import csv, datetime as dt, statistics as st
R='/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/3fcd60bc-4884-4590-bb4e-890e0eaea392/scratchpad/raw/'
def rd(f):
    with open(R+f) as h: return list(csv.DictReader(h))
d10=rd('dat2_10m.csv'); d7=rd('dat2_7m.csv')
t0=dt.datetime(2023,11,14,12,0,2)
td=lambda r: t0+dt.timedelta(minutes=10*(int(r['blk'])-1))
print(f"10m blocks {len(d10)} -> {len(d10)*10/1440:.1f} d ; 7m blocks {len(d7)} -> {len(d7)*10/1440:.1f} d")

def tab(rows,name):
    print(f"\n=== {name}: raw sample quality, 10-min blocks ===")
    print(f"{'day':<12}{'%samp min(corr)<70':>20}{'c1':>7}{'c2':>7}{'c3':>7}{'amp':>7}{'P(dBar)':>9}")
    d=dt.datetime(2023,12,18)
    while d<dt.datetime(2024,1,19):
        w=[r for r in rows if d<=td(r)<d+dt.timedelta(days=1)]
        if w:
            print(f"{d:%Y-%m-%d}  {100*st.median([float(r['f_min70']) for r in w]):>18.1f}%"
                  f"{st.mean([float(r['c1']) for r in w]):>7.1f}{st.mean([float(r['c2']) for r in w]):>7.1f}"
                  f"{st.mean([float(r['c3']) for r in w]):>7.1f}{st.mean([float(r['amp']) for r in w]):>7.1f}"
                  f"{st.mean([float(r['p']) for r in w]):>9.2f}")
        d+=dt.timedelta(days=1)
tab(d10,'MOP586 10 m (lost Dec 25 - Jan 19)')
tab(d7,'MOP586 7 m (99.8% valid)')
