# Dynamic Island

A macOS notch app that brings an interactive, living notch experience to your Mac — with integrated AI agent approvals, task tracking, and a weekly productivity dashboard.

## Features

### AI Agent Integration
- **Claude Code hook** — every tool use by Claude Code routes through the notch for approve/deny
- Pre-tool-use approval UI appears in the notch with one-click Approve / Deny
- Unix socket server (`/tmp/dinamic-island.sock`) handles the full request/response loop

### Task & Time Tracker
- Create tasks with **tags** (primary label) and an optional **parent project**
- Start/pause/complete timers per task directly from the notch
- Tag autocomplete with existing tags; project suggestions with create-new support

### Weekly Dashboard
- Bar chart of tracked hours per day (current week)
- Breakdown by **project → tags** with completion ratios and time totals
- Hover any tag row to remove the tag from all tasks
- Copy daily report to clipboard

### Notch Modules
- Music / Now Playing controls
- Calendar & upcoming events
- Battery & system HUDs
- Shelf (AirDrop-style drop target)
- Webcam preview

## Requirements

- macOS 14 Sonoma or later
- Mac with a notch (MacBook Pro 2021+, MacBook Air 2022+)

## Build

```bash
git clone https://github.com/javieralas5/dinamic-island.git
cd dinamic-island
open boringNotch.xcodeproj
```

Select the `boringNotch` scheme and build with Xcode 15+.

## Claude Code Hooks Setup

Install the hooks so the notch intercepts Claude Code tool calls:

```bash
mkdir -p ~/Library/Application\ Support/boringNotch/hooks
chmod +x hooks/*.sh
cp hooks/pre_tool_use.sh hooks/notification.sh hooks/stop.sh \
   ~/Library/Application\ Support/boringNotch/hooks/

# Symlink avoids path-with-spaces issues
mkdir -p ~/bin
ln -sf ~/Library/Application\ Support/boringNotch/hooks/pre_tool_use.sh \
       ~/bin/di-pre-tool-use
```

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": ".*",
      "hooks": [{ "type": "command", "command": "/Users/YOUR_USER/bin/di-pre-tool-use" }]
    }]
  }
}
```

Restart Claude Code for hooks to take effect.

## License

MIT — see [LICENSE](LICENSE).  
Third-party licenses: [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
