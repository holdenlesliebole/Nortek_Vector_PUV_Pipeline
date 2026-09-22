#!/bin/bash
# remove_verified_raw_cache_2026_09_21.sh
# Removes raw_cache/<DEPLOYMENT> directories whose every file exists on reefbreak at
# the same size (Research/STORAGE_AUDIT_2026-09-21.md, item C). raw_cache/ is a copy of
# server data made by L1_raw_to_qc/copy_raw_to_local.m; a session that needs a
# deployment re-caches it on demand.
#
# Verification is done per deployment, live against the mount, immediately before
# removal. A deployment is removed only if every non-empty local file matches a server
# file of the same name and size under that deployment's raw root. Empty (0-byte) local
# files are tolerated: they are truncated copies or junk, and the server copy is what
# counts. Any other mismatch skips the deployment and reports it.
#
# Usage:  scripts/remove_verified_raw_cache_2026_09_21.sh            # dry run, report only
#         scripts/remove_verified_raw_cache_2026_09_21.sh dry LPL24,SIO24B   # subset
#         scripts/remove_verified_raw_cache_2026_09_21.sh --delete   # verify and remove
set -u
cd "$(dirname "$0")/.." || exit 1
mount | grep -q ' /Volumes/group ' || { echo "reefbreak not mounted"; exit 1; }
MODE="${1:-dry}"
ONLY="${2:-}"   # optional comma-separated deployment list
python3 - "$MODE" "$ONLY" <<'PY'
import os,re,sys,shutil
mode=sys.argv[1]; only=set(x for x in sys.argv[2].split(',') if x)
V='/Volumes/group/PUV_data/Vector'
# literal roots from every config
roots=set()
for f in os.listdir('config'):
    if f.endswith('_config.m'):
        roots|=set(re.findall(r"cfg\.rawDataRoot\s*=\s*'(/Volumes/group[^']*)'",open('config/'+f).read()))
# archive deployments: TorreyOffshore_config.m builds root/sub from a table
txt=open('config/TorreyOffshore_config.m').read()
sarah=f'{V}/recopied/Sarah_LPL_2014-2023'
special={}
for m in re.finditer(r"reg\('(\w+)'\)\s*=\s*\{(server|fullfile\(sarah,'([^']+)','Raw Data'\)),\s*'([^']*)'",txt):
    dep,kind,yr,sub=m.groups()
    root=f'{V}/recopied' if kind=='server' else f'{sarah}/{yr}/Raw Data'
    special[dep]=[os.path.join(root,sub) if sub else root]
# legacy products and the reader test, documented in scripts/probe_ruby2d.m and L1_raw_to_qc/test_read_VEC.m
special['Ruby2D']=['/Volumes/group/Ruby2D/PUV/Level1_QC','/Volumes/group/Ruby2D/PUV/Level2_QC']
special['TORREY02_2019_test']=[f'{V}/recopied/TorreyPines2019-2020MOP582_10meter']
keep_files={'Ruby2D/legacy_bulk_582_6m.mat'}   # 238 KB derived file of unknown server location; kept
def server_size(cands, rel, f, want):
    # the same file name can exist under more than one root (e.g. Vector/ and Vector/retry/);
    # return the size that matches if any candidate does, else the last size seen
    seen=None
    for r in cands:
        for sp in (os.path.join(r, rel, f) if rel!='.' else os.path.join(r,f), os.path.join(r,f)):
            try: seen=os.path.getsize(sp)
            except OSError: continue
            if seen==want: return seen
    return seen
summary=[]
SENTINEL='/Volumes/group/PUV_data/Vector/Processed_HLB/manifest.csv'
for dep in sorted(os.listdir('raw_cache')):
    d=os.path.join('raw_cache',dep)
    if not os.path.isdir(d) or (only and dep not in only): continue
    if not os.path.exists(SENTINEL):
        print(f'\nMOUNT DROPPED before {dep}: stopping. Remount and rerun; removed deployments are skipped.'); break
    cands=special.get(dep, sorted(roots))
    n=ok=empty=0; bad=[]; kept=[]; total=0
    for dirpath,_,files in os.walk(d):
        rel=os.path.relpath(dirpath,d)
        for f in files:
            if f=='.DS_Store': continue
            key=os.path.join(dep, rel if rel!='.' else '', f).replace('/./','/')
            if key in keep_files: kept.append(key); continue
            lp=os.path.join(dirpath,f); sz=os.path.getsize(lp); n+=1; total+=sz
            if sz==0: empty+=1; continue
            ss=server_size(cands, rel, f, sz)
            if ss==sz: ok+=1
            else: bad.append((os.path.join(rel,f), sz, ss))
    verdict = 'REMOVABLE' if not bad and n>0 else 'SKIP'
    if kept: verdict += ' (keeps %d file)'%len(kept)
    summary.append((dep,n,total,ok,empty,len(bad),verdict))
    if mode=='--delete' and not bad and n>0:
        if kept:
            for dirpath,_,files in os.walk(d, topdown=False):
                for f in files:
                    key=os.path.join(dep, os.path.relpath(dirpath,d), f).replace('/./','/')
                    if key not in keep_files and f!='.DS_Store': os.remove(os.path.join(dirpath,f))
                for sub in os.listdir(dirpath):
                    p=os.path.join(dirpath,sub)
                    if os.path.isdir(p) and not os.listdir(p): os.rmdir(p)
        else:
            shutil.rmtree(d)
    for b in bad[:3]: print(f'   mismatch {dep}: {b}')
print(f'{"deployment":20s}{"files":>6s}{"GB":>7s}{"match":>6s}{"empty":>6s}{"bad":>5s}  verdict')
for s in summary: print(f'{s[0]:20s}{s[1]:6d}{s[2]/1e9:7.1f}{s[3]:6d}{s[4]:6d}{s[5]:5d}  {s[6]}')
rem=sum(s[2] for s in summary if s[6].startswith('REMOVABLE'))
print(f'\nremovable total: {rem/1e9:.1f} GB   mode: {"DELETED" if mode=="--delete" else "dry run (pass --delete to remove)"}')
PY
echo "raw_cache now: $(du -sh raw_cache 2>/dev/null | cut -f1)"
