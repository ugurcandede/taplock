<div align="center">
  <img src="assets/icon.png" alt="TapLock" width="80">
  <h1>TapLock</h1>
  <p>Temporarily disable keyboard and trackpad input on your Mac.<br><strong>No root required</strong></p>
  <br>
  <a href="https://github.com/ugurcandede/taplock/releases/latest"><img src="https://img.shields.io/github/v/release/ugurcandede/taplock?label=version&style=flat-square" alt="Version"></a>
  <a href="https://github.com/ugurcandede/taplock/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/ugurcandede/taplock/build.yml?style=flat-square" alt="Build"></a>
  <br>
  <img src="https://img.shields.io/badge/macOS-13.0%2B-000?style=flat-square&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Source%20Available-lightgrey?style=flat-square" alt="License"></a>
</div>

---
#### Releated
<p style="text-align: center">
  <a href="https://ugurcandede.github.io/taplock-app"><img src="https://img.shields.io/badge/Website-000?style=flat-square&logo=safari&logoColor=white" alt="Website"></a>
  <a href="https://github.com/ugurcandede/taplock"><img src="https://img.shields.io/badge/CLI%20Repo-000?style=flat-square&logo=github&logoColor=white" alt="CLI"></a>
  <a href="https://github.com/ugurcandede/homebrew-taplock"><img src="https://img.shields.io/badge/Homebrew%20Tap-FBB040?style=flat-square&logo=homebrew&logoColor=000" alt="Homebrew"></a>
</p>

---

## Install

```bash
brew tap ugurcandede/taplock
brew install taplock                # CLI
brew install --cask taplock-app     # Menu bar app
```

### Build from source

```bash
git clone https://github.com/ugurcandede/taplock.git
cd taplock
swift build -c release
# Binary at .build/release/taplock
```

---

## Features

| | Feature | Description |
|---|---|---|
| ⌨️ | **Input Blocking** | Block keyboard, trackpad, and mouse via CGEvent tap |
| ⏱️ | **Countdown Overlay** | Full-screen timer with clock display, customizable color |
| ♾️ | **Flexible Duration** | Seconds, minutes, or indefinite with 5 min safety auto-unlock |
| 🔅 | **Screen Dimming** | Reduce brightness to minimum during lock, restores on exit |
| 🔔 | **Sound Feedback** | Audio cues on lock start/end. Silent mode available |
| 🚨 | **Emergency Cancel** | Hold **⌘⌥⌃L** for 3 seconds to cancel — always works |

---

## Usage

```bash
taplock                          # Lock until cancelled (5 min safety)
taplock 30                       # Lock for 30 seconds
taplock 2m                       # Lock for 2 minutes
taplock 1m30s                    # Lock for 1 minute 30 seconds
```

### Options

| Option | Description |
|---|---|
| `--cancel` | Cancel an active lock session (from another terminal) |
| `--keyboard-only` | Block keyboard only, not trackpad |
| `--no-overlay` | Skip the full-screen overlay UI |
| `--delay <seconds>` | Wait before activating lock |
| `--color <value>` | Overlay color: name (`black`, `red`...) or hex (`fff`, `#FF0000`) |
| `--dim` | Reduce screen brightness to minimum |
| `--silent` | Disable sound effects |
| `-h, --help` | Show help |
| `-v, --version` | Show version |

### Examples

```bash
# Full cleaning mode: black screen, dimmed, silent
taplock --color black --dim --silent

# Keyboard only, 2 minutes, with 5s delay
taplock 2m --keyboard-only --delay 5

# Cancel from another terminal
taplock --cancel
```

### Emergency Cancel

Press **⌘⌥⌃L** (Cmd + Option + Ctrl + L) and hold for **3 seconds** to cancel at any time.

---

## How it works

- **CGEvent tap** at session level blocks keyboard, trackpad, mouse, and gesture events
- **PID file** at `~/Library/Caches/taplock/` enables cross-terminal cancel via `--cancel`
- **DispatchSource** signal handlers ensure input and brightness are always restored on exit

---

## Requirements

macOS 13.0 (Ventura) or later · Apple Silicon or Intel · Accessibility permission

## License

Source Available — free to use, not to modify or redistribute. See [LICENSE](LICENSE).
