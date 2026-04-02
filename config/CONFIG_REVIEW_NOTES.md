# Config Review Notes

Items to revisit before running L1 processing on NN24 data.

---

## Clock drift — 7 of 9 NN24 instruments have `clockDrift = NaN`

The clock drift correction in `PUV_raw_process.m` will be skipped for any instrument
with `NaN`. Check field notes/lab notebooks to see if any of these can be filled in:

| Instrument     | Status in notes                        |
|----------------|----------------------------------------|
| MOP580_5m      | Battery depleted — unrecoverable       |
| MOP580_7m      | Blank in DeploymentNotes2023-2024.xls  |
| MOP586_10m     | Blank in DeploymentNotes2023-2024.xls  |
| MOP586_15m     | "2 week clock drift!?" — ambiguous     |
| MOP651_5m      | Battery depleted — unrecoverable       |
| MOP651_7m      | Blank in DeploymentNotes2023-2024.xls  |
| MOP654_7m      | Blank in DeploymentNotes2023-2024.xls  |

Source: `/Volumes/group/DeploymentNotes/DeploymentNotes2023-2024.xls`, sheet 'All Data'

---

## MOP580_5m (NN24) — battery depletion

Battery depleted before recovery. Data record is likely truncated. Verify the end of
the time series before using this instrument in any analysis.

File prefix: `TORREY02` (unusual — all other NN24 instruments follow the standard
`{depth}M_{probeID}_MOP{line}` convention).

---

## Time-varying headings — two NN24 instruments

### MOP586_15m
- Heading shifted ~3 degrees during the Dec 28, 2023 storm event.
- Config uses initial heading of 40.0 degrees.
- If directional accuracy matters for this instrument, heading needs to be
  treated as a step-change at the storm date. Consider adding a
  `headingChangeDate` field to the config struct.

### MOP580_5m
- Heading shifted ~4 degrees over Dec 4–9, 2023 (84 → 80 degrees).
- Config uses nominal 76.5 degrees from deployment notes.
- Same caveat as above.

---

## MOP654.5 station code

`mopStation` is set to `'D0654'` (MOP 654.5 rounded). Verify this is the correct
identifier in the CDIP MOP database before running MOP comparisons for this instrument.

---

## Serial number ambiguity in TBR23

The TBR23_Notes.xlsx has no explicit serial number column. Serial numbers in
`TBR23_config.m` come from folder names on the lab server. The file prefix numbers
(e.g., 58002, 58602) appear to be Nortek **probe IDs**, not instrument serial numbers.
The folder-name numbers (e.g., 16739, 17042) are consistent with the instrument
serial numbers in the 2023 checkout spreadsheet and NN24 deployment notes.

For instruments where these differ, both are recorded in the config comments.

---

## .nc files — not used, can be skipped

The `save_initial_processingPUV_netcdf.m` step in `PUV_raw_process.m` is commented
out and has been confirmed unused. The Paper 1 pipeline loads `.mat` files only.
Do not re-enable `.nc` export unless needed for data sharing/archival.

---

## 3-hour detiding — abandoned

The `PUV_code_combined_3h_incoming.m` approach (NaN gap-filling + tidal fitting over
3-hour segments) left tidal artifacts and has been abandoned. The canonical L2 approach
is 17-minute (2048-sample @ 2 Hz) segments with detrending. Do not reintroduce tidal
fitting. Archive `PUV_code_combined_3h_incoming.m`.
