# `config/` — deployment configuration

Every deployment the pipeline can process is defined here. The pipeline code
itself is site-agnostic; all site- and instrument-specific parameters live in
these config functions.

## How it works

- **`deployment_registry.m`** maps a short key (e.g. `'TOR24S'`) to a config
  function (`@TOR24S_config`). The drivers look up `deployment_name` here:

  ```matlab
  reg = deployment_registry();
  cfg = reg('TOR24S')();     % returns the config struct
  ```

- **`<SITE>_config.m`** returns a `cfg` struct with deployment-level fields
  (`name`, `fs`, `rawDataRoot`, `outputDir`, optional `qcOpts`) and a
  `cfg.instruments(k)` array — one entry per instrument (label, file prefix,
  `latlon`, `doffp`, heading, shore-normal, optional offshore `refStation`, …).

- **`cfg.name`** drives the output and cache folder names
  (`outputs/L{1..4}/<cfg.name>/`, `raw_cache/<cfg.name>/`), so it is the
  canonical identity of a processed deployment.

## Adding your own deployment

1. Copy **`TEMPLATE_config.m`** (fully commented, site-agnostic) to
   `config/<SITE>_config.m` and rename the function to match.
2. Fill in every `<<< EDIT >>>` field for each instrument.
3. Register it with one line in `deployment_registry.m`:
   `registry('<SITE>') = @<SITE>_config;`

See **`../docs/NEW_DEPLOYMENT.md`** for the full walkthrough (metadata checklist,
shore-normal without CDIP/MOP, temperature QC, offshore reference, troubleshooting),
and **`CONFIG_REVIEW_NOTES.md`** / **`DOFFP_LOOKUP_CHECKLIST.md`** for
deployment-specific gotchas.

## Naming convention

Keys follow `SITE + year + optional season letter` (e.g. `TOR24S` = Torrey
spring 2024, `SIO24A–C` = SIO Pier 2024 chronological). A few keys also have
convenience aliases in the registry; the header of `deployment_registry.m` is
the authoritative list.
