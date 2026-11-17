# OnTop

A lightweight, open-source system monitor that lives in the macOS menu bar —
a tiny FOSS take on apps like [Stats](https://github.com/exelban/stats), showing
a slice of the kind of info you'd get from `btop`.

One stat rides in the menu bar. Click it and a dropdown shows the rest, live.
Pick any one and it becomes the stat shown in the bar.

```
  ▓ 42%                 ← menu-bar slot (RAM by default)
 ┌─────────────────────────────┐
 │ ✓ RAM      42%  ·  6.8/16 GB │   ← click a row to promote it to the bar
 │   CPU      18%  ·  10 cores  │
 │   GPU      0%  · tiler 0%    │
 │   Power    11 W · system     │
 │   Temp     47°C avg · 52 pk  │
 │   Disk     63%  ·  620/994GB │
 │   Network  ↓1.2 MB/s ↑0.3 MB │
 │   FPS      120 · display     │
 │  ───────────────────────────│
 │   Update Interval         ▸  │
 │   Launch at Login            │
 │  ───────────────────────────│
 │   About OnTop                │
 │   Quit OnTop            ⌘Q   │
 └─────────────────────────────┘
```

## Stats

| Stat    | Source | Notes |
|---------|--------|-------|
| RAM     | `host_statistics64` | Matches Activity Monitor's "Memory Used" (app + wired + compressed). |
| CPU     | `host_processor_info` | Total busy %, averaged across logical cores. |
| GPU     | IORegistry (`IOAccelerator`) | "Device Utilization %" with tiler/renderer breakdown. |
| Power   | AppleSMC | Total system draw in watts from the main DC rail (`PSTR`/`PDTR`/`PD0R`, resolved per model). |
| Temp    | AppleSMC | Averages discovered CPU sensors. Falls back to the OS thermal-pressure state when the SMC exposes no readable sensor. |
| Disk    | URL volume capacity | Used % of the boot volume. |
| Network | `getifaddrs` | Down/up throughput; fixed-width `K/M/G/T` so the slot never jitters. |
| FPS     | `CVDisplayLink` | Frames presented per second on the main display — its live refresh rate (e.g. 60 or 120), not any single app's render rate. |

All readings use documented macOS APIs — no private frameworks, no helper
daemon, no network access.

## Build & run

Requirements: macOS 13+, the Swift toolchain (`xcode-select --install` is enough).

```sh
make run        # build OnTop.app and launch it
make app        # just build ./OnTop.app
make install    # copy OnTop.app into /Applications
make sensors    # list the SMC temperature sensors on this machine
make icon       # regenerate Resources/AppIcon.icns from Tools/make_icon.swift
```

The app icon is drawn from code (`Tools/make_icon.swift`, CoreGraphics) — four
ascending bars in a green→red utilization gradient on a dark tile. Tweak the
colors or shapes there and run `make icon` to regenerate.

To quit, use **Quit OnTop** in the dropdown (⌘Q while it's open).

The menu-bar slot and refresh interval are remembered between launches.

## Architecture

Each stat is a `StatReader` (`id`, `name`, SF Symbol, and a `sample()` that
returns a `StatReading`). `StatusController` polls every reader on a timer,
renders the primary one into the `NSStatusItem`, and fills the dropdown. Adding
a new stat is one file plus one line in the `readers` array.

```
Sources/OnTop/
  main.swift              app entry (+ --list-sensors diagnostic)
  AppDelegate.swift
  StatusController.swift   menu-bar item, dropdown, timer, promote-to-primary
  StatReader.swift         protocol + formatting helpers
  SMC.swift                read-only AppleSMC client
  Readers/
    MemoryReader.swift
    CPUReader.swift
    TemperatureReader.swift
    DiskReader.swift
    NetworkReader.swift
```

## Roadmap

- Per-component power (CPU/GPU/ANE watts) and efficiency-core temps via IOReport
- Per-core CPU breakdown and small inline sparklines in the bar
- Swap, memory-pressure, and load-average readers
- Preferences window (which stats appear, units, colors)
- Signed/notarized release builds

## License

MIT — see [LICENSE](LICENSE).
