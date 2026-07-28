"""Patch the stored LATLON in L1/L2/L4 to match the configs, in place.

LATLON is metadata everywhere except L4_xspec, which computes instrument pair
separations from it (PUV_L4_xspec.m:205). Nothing in L1-L4 single-instrument
processing reads it, so correcting a coordinate needs no reprocessing -- only
this patch plus an xspec rebuild.

The files are 0.3-1 GB each and HDF5 underneath, so the 2-element dataset is
overwritten in place rather than re-saving the whole .mat.

Usage:  python3 scripts/patch_stored_latlon.py [--apply]
        (default is a dry run)
"""
import csv, os, sys
import h5py

CSV = ('/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research-PUV-'
       'Pipeline/ea0c0e32-c069-491b-9b57-401726da413a/scratchpad/config_latlon.csv')
ROOT = 'outputs'
LEVELS = [('L1', 'L1/{d}/{l}_processed.mat', 'PUV'),
          ('L2', 'L2/{d}/{l}_L2.mat',        'L2'),
          ('L4', 'L4/{d}/{l}_L4.mat',        'L4')]
TOL = 1e-6           # degrees; below this the stored value already agrees
APPLY = '--apply' in sys.argv

rows = list(csv.DictReader(open(CSV)))
print(f'{len(rows)} registered records in the config dump')
print(f"mode: {'APPLY' if APPLY else 'DRY RUN'}\n")

nchg = nok = nmiss = 0
for r in rows:
    d, l = r['deployment'], r['label']
    lat, lon = float(r['lat']), float(r['lon'])
    for lvl, tpl, root in LEVELS:
        p = os.path.join(ROOT, tpl.format(d=d, l=l))
        if not os.path.isfile(p):
            nmiss += 1
            continue
        try:
            # Read-only first. Opening 'r+' updates the file mtime even when
            # nothing is written, and the pipeline's staleness audits compare
            # L2-vs-L3/L4 mtimes -- so only reopen for writing if a value
            # actually differs.
            with h5py.File(p, 'r') as h:
                if root not in h or 'LATLON' not in h[root]:
                    print(f'  {lvl} {d}/{l}: no LATLON dataset')
                    continue
                shaped = h[root]['LATLON'][()]
                cur = shaped.ravel()
                if abs(cur[0]-lat) < TOL and abs(cur[1]-lon) < TOL:
                    nok += 1
                    continue

            shift_m = (((lat-cur[0])*110904)**2 + ((lon-cur[1])*93435)**2)**0.5
            print(f'  {lvl} {d}/{l}: [{cur[0]:.5f} {cur[1]:.5f}] -> '
                  f'[{lat:.5f} {lon:.5f}]  ({shift_m:.0f} m)')
            if APPLY:
                flat = shaped.ravel().copy()
                flat[0], flat[1] = lat, lon
                with h5py.File(p, 'r+') as h:
                    h[root]['LATLON'][...] = flat.reshape(shaped.shape)
            nchg += 1
        except Exception as e:
            print(f'  {lvl} {d}/{l}: ERROR {type(e).__name__}: {e}')

print(f'\n{nchg} datasets {"patched" if APPLY else "would change"}, '
      f'{nok} already correct, {nmiss} files absent')
if not APPLY:
    print('re-run with --apply to write')
