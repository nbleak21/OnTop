# Changelog

All notable changes to OnTop are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Per-component power (CPU/GPU/ANE watts) and efficiency-core temps via IOReport.
- Per-core CPU breakdown and small inline sparklines in the bar.
- Swap, memory-pressure, and load-average readers.
- Preferences window (which stats appear, units, colors).
- Signed / notarized release builds.

## [0.1.0] — 2026-11-22

Initial release.

### Added
- Menu-bar system monitor: one stat rides in the bar, a dropdown shows the rest
  live, and clicking a row promotes it to the bar. Choice and refresh interval
  persist between launches.
- Eight stats, all from documented macOS APIs (no private frameworks, no helper
  daemon, no network access): **RAM**, **CPU**, **GPU**, **Power** (watts),
  **Temperature**, **Disk**, **Network**, **FPS**.
- Code-drawn app icon (`Tools/make_icon.swift`, CoreGraphics).
- Makefile targets for building the app, a universal (arm64 + x86_64) binary,
  and Developer ID signing / notarization.
- `--list-sensors` and `--list-power` diagnostics for porting the SMC-based
  readers to new Mac models.

[Unreleased]: https://github.com/nbleak21/OnTop/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nbleak21/OnTop/releases/tag/v0.1.0
