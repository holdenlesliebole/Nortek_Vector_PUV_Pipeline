# PUV Pipeline — Deployment Database Overview

**Prepared for:** Brian Woodward
**Date:** April 5, 2026
**Purpose:** Verify that our automated processing results match field knowledge before finalizing the dataset.

---

## What This Document Covers

The PUV Pipeline ingests raw Nortek AWAC burst files, applies clock-drift correction, tilt-based coordinate rotation, and quality control to produce cleaned wave-measurement time series. This document summarizes **every instrument deployment** we have processed so far: **40 instruments across 20 deployments**. Of those, **33 processed successfully** and **7 failed** due to hardware issues (bent pipes, dead batteries, or instruments knocked over).

Please review the table below and the questions at the end. Any corrections or additional context would be very helpful.

---

## Master Instrument Table

### La Jolla (LPL) Deployments

| Deployment | Instrument | S/N | Date Range | Coord | doffp (m) | Clock Drift | L1 Status | Notes |
|---|---|---|---|---|---|---|---|---|
| LPL23 | LPL_8m | 15032 | Dec 2023 -- Feb 2024 | XYZ | 0.88 | NaN | OK | MOP D0591. Tilt < 1 deg. |
| LPL24 | LPL_8m | 12412 | Dec 2024 -- Feb 2025 | ENU | 0.75 | NaN | OK | MOP D0591. Tilt correction applied (pitch = -1.4 deg). |
| LPL25A | LPL_8m | 12412 | Mar -- Jun 2025 | ENU | 0.85 | NaN | OK | MOP D0591. Tilt correction applied (pitch = -1.4 deg). |
| LPL25B | LPL_8m | 12412 | Dec 2025 -- Feb 2026 | XYZ | 0.80 | NaN | OK | MOP D0591. Tilt < 1 deg. |

### Torrey Pines Winter 2023-24 (TOR23W) — Nov 2023 to Jan/Feb 2024

Previously bundled with the Solana Beach instruments as "NN24" (El Niño
and Beach Nourishment campaign); split into TOR23W and SOL23 by location
in April 2026.

| Deployment | Instrument | S/N | Date Range | Coord | doffp (m) | Clock Drift | L1 Status | Notes |
|---|---|---|---|---|---|---|---|---|
| TOR23W | MOP580_5m | 17047 | Nov 2023 -- Jan/Feb 2024 | XYZ | 0.60 | NaN (battery depleted) | OK | Tilt < 1 deg. |
| TOR23W | MOP580_7m | 17042 | Nov 2023 -- Jan/Feb 2024 | XYZ | 0.90 | NaN | OK | Tilt < 1 deg. |
| TOR23W | MOP586_5m | 17043 | Nov 2023 -- Jan/Feb 2024 | XYZ | 0.65 | 5s fast | OK | Tilt < 1 deg. |
| TOR23W | MOP586_7m | 16739 | Nov 2023 -- Jan/Feb 2024 | XYZ | 0.67 | 6s fast | OK | Tilt correction (pitch = 1.3 deg). |
| TOR23W | MOP586_10m | 16306 | Nov 2023 -- Jan/Feb 2024 | XYZ | 1.00 | NaN | OK | Single burst file. Tilt correction (pitch = 1.6 deg). |
| TOR23W | MOP586_15m | 15277 | Nov 2023 -- Jan/Feb 2024 | XYZ | 1.00 | NaN ("2 week clock drift!?") | OK | Tilt correction (pitch = 1.3 deg). |

### Solana Beach Winter 2023-24 (SOL23) — Nov 2023 to Jan 2024

| Deployment | Instrument | S/N | Date Range | Coord | doffp (m) | Clock Drift | L1 Status | Notes |
|---|---|---|---|---|---|---|---|---|
| SOL23 | MOP651_5m | 17045 | Nov 2023 -- Jan 2024 | XYZ | 0.88 | NaN (battery depleted) | **FAILED** | No valid pressure data. Instrument lost 2 years, found Dec 2025 with severely bent pipe. |
| SOL23 | MOP651_7m | 16310 | Nov 2023 -- Jan 2024 | XYZ | 1.09 | NaN | OK | Tilt correction (pitch = -3.1 deg, roll = 4.7 deg). |
| SOL23 | MOP654_7m | 17036 | Nov 2023 -- Jan 2024 | XYZ | 1.08 | NaN | OK | Tilt correction (pitch = -0.5 deg, roll = -3.6 deg). |

### Scripps (SIO) Deployments

| Deployment | Instrument | S/N | Date Range | Coord | doffp (m) | Clock Drift | L1 Status | Notes |
|---|---|---|---|---|---|---|---|---|
| SIO24A | SIO_6m | 16310 | Mar -- May 2024 | XYZ | 0.79 | NaN | OK | MOP D0511. Tilt < 1 deg. |
| SIO24B | SIO_6m | 16310 | Jun -- Jul 2024 | XYZ | 0.79 | NaN | **FAILED** | Tilted 32 deg (pitch = -22 deg, roll = 23 deg). Beam correlations < 10%. Knocked over. |
| SIO24C | SIO_6m | 15033 | Oct -- Dec 2024 | XYZ | 0.79 | NaN | **FAILED** | No valid pressure data. Beam correlations very low. Battery depleted 12/31/2024. |
| SIO25A | SIO_6m | 15277 | Jan -- Mar 2025 | XYZ | 0.79 | NaN | **FAILED** | Upside down at start (pitch = -168 deg), righted itself, but beam correlations stayed low. Power pin corrosion noted. |
| SIO25B | SIO_6m | 15277 | Apr -- Jun 2025 | XYZ | 0.79 | NaN | OK | Tilt < 1 deg. |
| SIO25C | SIO_6m | 17042 | Jul -- Aug 2025 | XYZ | 0.79 | NaN | OK | Tilt < 1 deg. Only 0.7 days of data (battery cutoff in burst 1). |
| SIO25D | SIO_6m | 17042 | Sep -- Nov 2025 | XYZ | 0.79 | NaN | OK | Tilt correction (pitch = -1.1 deg). 83 days of data. |
| SIO25E | SIO_6m | 17047 | Dec 2025 -- Feb 2026 | XYZ | 0.90 | NaN | OK | Tilt < 1 deg. 93 days of data. |

### Solana Beach (SOL) Deployments

| Deployment | Instrument | S/N | Date Range | Coord | doffp (m) | Clock Drift | L1 Status | Notes |
|---|---|---|---|---|---|---|---|---|
| SOL24 | MOP654_7m | 17036 | Dec 2024 -- Feb 2025 | ENU | 0.89 | NaN | OK | MOP D0654. Tilt correction (pitch = -4.4 deg). |
| SOL25A | MOP654_7m | 17036 | Mar -- May 2025 | XYZ | 0.81 | NaN | OK | MOP D0654. Tilt correction (pitch = -0.1 deg, roll = 1.8 deg). |
| SOL25B | MOP654_7m | 17042 | Dec 2025 -- Feb 2026 | XYZ | 1.00 | NaN | OK | MOP D0654. Tilt correction (pitch = 0.2 deg, roll = -2.4 deg). |

### Torrey Pines — Beach Recovery (TBR23) — May to Aug 2023

| Deployment | Instrument | S/N | Date Range | Coord | doffp (m) | Clock Drift | Median Depth (m) | L1 Status | Notes |
|---|---|---|---|---|---|---|---|---|---|
| TBR23 | MOP580_5m | 16739 | May -- Aug 2023 | XYZ | 0.77 | 16.6s | 6.2 | OK | Tilt correction (pitch = 0.5 deg, roll = -2.0 deg). |
| TBR23 | MOP580_7m | 58002 | May -- Aug 2023 | XYZ | 0.77 | 9.8s | 8.3 | OK | Tilt < 1 deg. |
| TBR23 | MOP586_5m | 17042 | May -- Aug 2023 | XYZ | 0.76 | 4.4s | 5.5 | OK | Tilt correction (pitch = -0.2 deg, roll = -3.8 deg). |
| TBR23 | MOP586_7m | 58602 | May -- Aug 2023 | XYZ | 0.75 | 11.3s | 8.3 | OK | Tilt correction (pitch = -0.6 deg, roll = -2.4 deg). |

### Torrey Pines — Spring 2024 (TOR24S) — Feb to May 2024

| Deployment | Instrument | S/N | Date Range | Coord | doffp (m) | Clock Drift | L1 Status | Notes |
|---|---|---|---|---|---|---|---|---|
| TOR24S | MOP580_7m | 17042 | Feb -- May 2024 | XYZ | 0.72 | NaN | OK | Tilt correction (pitch = -2.2 deg, roll = 2.9 deg). |
| TOR24S | MOP586_5m | 16737 | Feb -- May 2024 | XYZ | 0.63 | NaN | OK | Tilt correction (pitch = -4.8 deg). |
| TOR24S | MOP586_7m | 16739 | Feb -- May 2024 | XYZ | 0.70 | NaN | OK | Tilt correction (pitch = 0.5 deg, roll = -1.2 deg). |
| TOR24S | MOP586_10m | 15033 | Feb -- May 2024 | XYZ | 0.79 | NaN | OK | Tilt correction (pitch = 0.1 deg, roll = -1.2 deg). |
| TOR24S | MOP586_15m | 15277 | Feb -- May 2024 | XYZ | 0.74 | NaN | **FAILED** | No valid pressure data. Pipe issues noted in deployment notes. |

### Torrey Pines — Winter 2024 (TOR24W) — Nov 2024 to Feb 2025

| Deployment | Instrument | S/N | Date Range | Coord | doffp (m) | Clock Drift | L1 Status | Notes |
|---|---|---|---|---|---|---|---|---|
| TOR24W | MOP586_5m | 16739 | Nov 2024 -- Feb 2025 | XYZ | 0.77 | NaN | **FAILED** | No valid pressure data. "Too buried to recover" per Brian's email 2/27/2025. Pipe bent 12/22/2024 by kelp. |
| TOR24W | MOP586_7m | 16310 | Nov 2024 -- Feb 2025 | XYZ | 0.63 | NaN | OK | Tilt < 1 deg. 70.8 days of data. |
| TOR24W | MOP586_10m | 16737 | Nov 2024 -- Feb 2025 | XYZ | 0.78 | NaN | OK | Tilt correction (pitch = -4.8 deg). 67.3 days of data. |
| TOR24W | MOP586_15m | 17047 | Nov 2024 -- Feb 2025 | XYZ | 0.75 | NaN | OK | Tilt < 1 deg. 66.1 days of data. |

### Torrey Pines — Spring 2025 (TOR25S) — Mar to Jun 2025

| Deployment | Instrument | S/N | Date Range | Coord | doffp (m) | Clock Drift | L1 Status | Notes |
|---|---|---|---|---|---|---|---|---|
| TOR25S | MOP586_5m | 15033 | Mar -- Jun 2025 | XYZ | 0.63 | NaN | **FAILED** | No valid pressure data. Pipe bent, kelp blockage. |
| TOR25S | MOP586_10m | 16737 | Mar -- Jun 2025 | XYZ | 0.86 | NaN | OK | Tilt correction (pitch = -4.3 deg, roll = 1.7 deg). 67.3 days. |
| TOR25S | MOP586_15m | 17047 | Mar -- Jun 2025 | XYZ | 0.80 | NaN | OK | Tilt < 1 deg. 66.8 days. |

---

## Summary Statistics

| | Count |
|---|---|
| Total deployments | 21 |
| Total instruments | 38 |
| L1 processing succeeded | 33 |
| L1 processing failed | 5 |
| Unique serial numbers | 16 |
| Instruments with clock drift measured | 6 (TBR23 + two TOR23W instruments) |
| Instruments with tilt correction applied | 22 |

### Failed Instruments

| Deployment | Instrument | S/N | Failure Reason |
|---|---|---|---|
| SOL23 | MOP651_5m | 17045 | Battery depleted early. Instrument lost 2 years, pipe severely bent. |
| SIO24B | SIO_6m | 16310 | Knocked over (32 deg tilt). Beam correlations < 10%. |
| SIO24C | SIO_6m | 15033 | Battery depleted 12/31/2024. All beam correlations very low. |
| SIO25A | SIO_6m | 15277 | Started upside down (pitch = -168 deg). Power pin corrosion. Beam correlations stayed low. |
| TOR24S | MOP586_15m | 15277 | No valid pressure data. Pipe issues. |
| TOR24W | MOP586_5m | 16739 | No valid pressure data. Buried, pipe bent by kelp. |
| TOR25S | MOP586_5m | 15033 | No valid pressure data. Pipe bent, kelp blockage. |

*7 individual instrument-deployment failures across 40 total instrument-deployments.*

---

## Questions for Brian

1. **SIO24B (Jun--Jul 2024, S/N 16310):** Was this instrument knocked over during deployment? Our data shows pitch = -22 deg and roll = 23 deg for the entire record, with beam correlations below 10%. We flagged this as unusable.

2. **SIO24C (Oct--Dec 2024, S/N 15033):** Battery depleted 12/31/2024. Was there any valid data before depletion? Our pipeline shows all beam correlations below 70% for the entire record.

3. **SIO25A (Jan--Mar 2025, S/N 15277):** The instrument appears upside down at the start of the record (pitch = -168 deg), then rights itself partway through. But beam correlations stayed low even after it was upright. Was there a sensor issue during this deployment? Your email mentioned "data looks good" -- could you clarify what looked OK from the field side?

4. **TOR24S MOP586_15m (S/N 15277):** Can you confirm this instrument had no usable data? The deployment notes mention pipe issues but we want to make sure we are not missing a workaround.

5. **SOL23 MOP651_5m (S/N 17045):** Confirmed dead in our pipeline -- battery depleted early in the winter 2023-24 Solana deployment, instrument was lost for 2 years, found Dec 2025 with severely bent pipe. Any chance of partial data recovery, or should we mark this as permanently lost?

6. **General -- clock drift for battery-depleted instruments:** For instruments where clock drift = NaN because the battery died before recovery (no end-time comparison possible), is there any alternative source for drift estimation? Logbook entries, GPS checks, anything we could use?

---

## Processing Notes

These notes describe how the pipeline handles a few key steps. Included here so Brian can flag anything that does not match what he sees in the field.

### Tilt Quality Control

We use a **variability-based** tilt threshold rather than a fixed absolute cutoff. Specifically:

- A 2-degree rolling standard deviation threshold flags segments where the instrument is **wobbling** (unstable mount, wave action on the pipe, etc.).
- Stable tilts -- even up to 30 degrees -- are **not** automatically rejected. Instead, we apply a 3D coordinate rotation to correct the velocity measurements for the known tilt.
- This means an instrument that is leaning at a constant angle (e.g., SOL24 at pitch = -4.4 deg) still produces good data, while an instrument that is rocking back and forth gets flagged.

### Instrument Height Above Bed (doffp)

All doffp values are sourced from the **DeploymentNotes spreadsheets** that Brian maintains. If any of these values look wrong in the table above, please let us know -- they directly affect the depth calculation and wave-height estimates.

### Shore-Normal Rotation

Directional wave parameters require rotating velocities into a shore-normal coordinate frame. We pull the shore-normal angle from **CDIP THREDDS metadata** for each MOP station. Note: the CDIP THREDDS server is currently down, so we will re-run the shore-normal rotation step once it comes back online. Current results use the last-cached angles.

### Overall Success Rate

**33 out of 40** instrument-deployments (82.5%) processed successfully through L1. The 7 failures are all hardware-related (bent pipes, dead batteries, knocked-over instruments, burial) rather than software issues.
