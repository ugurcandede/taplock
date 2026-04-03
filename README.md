# CleanLock

Temporarily disable keyboard and trackpad input while cleaning your Mac. No root required.

## Install

### Homebrew

```bash
brew tap ugurcandede/cleanlock
brew install cleanlock
```

### Build from source

Requires Swift 5.9+ (Xcode Command Line Tools is enough, no Xcode needed).

```bash
git clone https://github.com/ugurcandede/cleanlock.git
cd cleanlock
swift build -c release
# Binary is at .build/release/cleanlock
```

## Usage

```bash
cleanlock                          # Lock until cancelled (safety auto-unlock: 5m)
cleanlock 30                       # Lock for 30 seconds
cleanlock 2m                       # Lock for 2 minutes
cleanlock 1m30s                    # Lock for 1 minute 30 seconds
```

### Options

```
--cancel            Cancel an active lock session (from another terminal)
--keyboard-only     Block keyboard only, not trackpad
--no-overlay        Skip the full-screen overlay UI
--delay <seconds>   Wait before activating lock
--color <value>     Overlay color: name (black, red, blue...) or hex (000, #fff, FF0000)
--dim               Reduce screen brightness to minimum during lock
--silent            Disable sound effects
-h, --help          Show help
-v, --version       Show version
```

### Examples

```bash
# Clean your screen with a pure black background
cleanlock --color 000000

# Full cleaning mode: black screen, dimmed brightness, no sound
cleanlock --color 000000 --dim --silent

# Lock keyboard only for 2 minutes, with 5 second delay to switch windows
cleanlock 2m --keyboard-only --delay 5

# Cancel an active session from another terminal
cleanlock --cancel
```

### Emergency Cancel

Press **⌘⌥⌃L** (Cmd + Option + Ctrl + L) and hold for **3 seconds** to cancel the lock at any time.

## Permissions

CleanLock requires **Accessibility** permission to block input. On first run, it will guide you through granting this in System Settings > Privacy & Security > Accessibility.

## How it works

- **Keyboard & trackpad blocking** via `CGEvent` tap at session level
- **Cursor locking** — cursor is hidden and pinned to screen center during lock
- **Full-screen overlay** — semi-transparent countdown timer with clock (customizable color)
- **Sound feedback** — system sounds on lock start/end
- **Brightness control** — dims screen to minimum during lock, restores on exit
- **IPC** — PID file at `~/Library/Caches/cleanlock/` for cross-terminal cancel via `--cancel`
- **Safety** — DispatchSource signal handlers always restore input and brightness before exit

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel

## License

MIT
