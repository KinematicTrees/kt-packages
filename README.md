# kt-packages

Public package repository for Kinematic Trees release artifacts.

## What this repo is for
- Publishing versioned module packages and binary release artifacts.
- Keeping release metadata (checksums, provenance, SBOM) with each release.
- Providing a predictable layout for package consumers and tooling.

## Repository structure
- `modules/<module>/<version>/<platform>/`
- `modules/<module>/docs/`
- `runtimes/<runtime>/<version>/<platform>/`
- `tools/<tool>/<version>/<track>/<platform>/`

## Currently packaged modules
- `ik-control` — versions: `0.1.0`
- `ik-runtime` — versions: `0.1.0`
- `model-loader` — versions: `0.1.0`
- `viewer-runtime` — versions: `0.1.0`

## Other packaged artifacts
- Runtimes:
  - `node` — versions: `20.11.1`
- Tools:
  - `kt-cli` — versions: `1.2.0-build.29`, `1.2.0-build.4195`, `1.2.0-build.4197`, `1.2.0-build.4199`, `1.2.0-build.4201`, `1.2.0-build.4205`, `1.2.0-build.4211`, `1.2.0-build.4215`, `1.2.0-build.4217`, `1.2.0-build.4219`, `1.2.0-build.4221`, `1.2.0-build.4228`, `1.2.0-build.4249`, `1.2.0-build.4283`

## Notes
This repo is for packaged release outputs. Source code lives in the corresponding development repositories.
