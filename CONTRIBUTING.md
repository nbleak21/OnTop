# Contributing to OnTop

Thanks for your interest in improving OnTop. It's a small, single-target Swift
package, so contributing is low-ceremony.

## Development setup

Requirements: macOS 13+ and the Swift toolchain (`xcode-select --install`).

```sh
git clone https://github.com/nbleak21/OnTop.git
cd OnTop
make run            # build OnTop.app and launch it
swift build         # or just compile
```

Useful targets: `make app`, `make universal`, `make sensors`, `make power`,
`make icon` (see the README for what each does).

## Adding a stat

Each stat is a `StatReader` — an `id`, a `name`, an SF Symbol, and a `sample()`
that returns a `StatReading`. To add one:

1. Create `Sources/OnTop/Readers/<Name>Reader.swift` implementing `StatReader`.
2. Register it with one line in the `readers` array in `StatusController.swift`.

That's the whole extension point — one file plus one line.

## Project principles

Please keep these invariants, which are a selling point of the app:

- **Documented, user-space APIs only** — no private frameworks, no helper daemon,
  no entitlements, no `sudo`.
- **No network access.** OnTop reads local system state and nothing else.
- Hardware-specific logic should *discover* keys at runtime where possible (see
  `TemperatureReader` and `PowerReader`) rather than hardcoding one machine.

## Code conventions

- Target macOS 13+ and the pinned `swift-tools-version` in `Package.swift`.
- Every Swift source carries the 2-line SPDX MIT header; keep it on new files.

## Submitting changes

1. Branch off `main`.
2. Make the change; ensure `swift build -c release` succeeds (CI runs this).
3. Open a pull request describing the stat or behaviour affected. If it's a new
   power/temperature key for a specific Mac, say which model you tested on.

By contributing, you agree your contributions are licensed under the MIT License
(see [`LICENSE`](LICENSE)).
