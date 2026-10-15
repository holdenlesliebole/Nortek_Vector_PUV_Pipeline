# Catalog change entries

Every change to the published catalog (`/Volumes/group/PUV_data/Vector/Processed_HLB/`)
is explained by an entry in this folder. `scripts/copy_to_server.m` refuses to
publish any file whose sha256 differs from the server manifest unless a
**pending** entry names it, and copies each entry's text into the server's
`CHANGELOG.md` under the new catalog version. After a successful push the
entry's status becomes `published <version>`. Entries are never deleted: they
are the record of why the catalog changed.

## Rule: `outputs/` is written only by this pipeline

No other repository, notebook or hand edit may write into `outputs/` (for
example, Paper_1 must not rewrite an L4 or L3 field in place). Every output file
carries a provenance sidecar `<file>.prov.json` with the sha256 of the bytes the
pipeline wrote; a file whose bytes differ is refused at push time as **modified
outside the pipeline**. This rule exists because Paper_1 once rewrote the TBR23
`L4.ref` in place, and the next rebuild silently reverted it: neither the edit
nor its loss was visible anywhere. To change an output, change the pipeline
code or config and rebuild.

## Entry format

One Markdown file per change, named `<YYYY-MM-DD>_<slug>.md`:

````markdown
# Short title of the change

```catalog-change
status: pending
files:
  - L4/TBR23/*
  - L3/*/*_L3.mat
code_ack:
  - L3: settling velocity now F&C nominal-diameter constants (C1 20, C2 1.1)
fallback_ack: false
```

What changed and why, in a few sentences.

How big the change is, with numbers from the verification (for example:
"TBR23 MOP580_5m R2_IG median 1.007 -> 1.026; Hs_IG median -0.4 mm").

How to tell an old copy from a new one if it is not just the sha256 (for
example: "new L3 files carry transport_params.ws_C1 = 20").
````

- `files`: patterns over `<level>/<deployment>/<file>` (level is L1, L2, L3, L4
  or L4_xspec; `*` matches within one path part). Every file the push publishes
  with a changed sha256 must match a pattern of some pending entry.
- `code_ack`: levels whose code changed since the files' build commit, with a
  reason. Without it, `check_prov` refuses a file whose level code changed after
  it was built (`SOFT` refusal).
- `changes`: omit (or `true`) for an entry that explains changed files. Set
  `changes: false` for an acknowledgement-only entry (for example code edits that
  change no output values): its `code_ack`/`fallback_ack` apply to the files it
  names, but it does not count as naming a changed sha256, so any file whose bytes
  changed is still refused unless another entry describes that change.
- `fallback_ack`: `true` only when the change knowingly publishes a build that
  recorded a fallback (for example a site with no CDIP shore-normal).
- A forced push (`forceReasons` in `copy_to_server`) writes its reason into
  `CHANGELOG.md` verbatim; use it rarely.
