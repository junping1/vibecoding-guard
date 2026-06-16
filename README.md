# Vibe Coding Guard

A tiny macOS menu bar app that keeps your Mac awake while Codex or Claude Code is open, so long agent runs finish even when you step away.

It works automatically. Whenever Codex or Claude Code is running, your Mac stays awake; once you quit them, it sleeps as usual. It detects whether those tools are **open** — it can't tell whether they're actively working — so it keeps the Mac awake the whole time they're running. There's nothing to set up.

It can also:

- **Always keep awake** — one toggle to keep the Mac awake no matter what, until you turn it off.
- **Keyboard Lock** — block the keyboard during a run so a pet or child can't interrupt it (press ⌘⌥⌃L to unlock).
- **Keep running with lid closed** — keep working with the lid shut (desk only; it pauses automatically if the Mac gets too hot).
- Let the display sleep after idle time, and warn before the battery gets low.

VCG asks only when a feature needs help from macOS:

- Notification banners are optional for battery alerts.
- Accessibility is needed only for Keyboard Lock.
- Closed-lid work installs a one-time, narrow permission for VCG's exact `pmset` commands, with a Remove button shown afterward.

VCG asks only when a feature needs help from macOS:

- Notification banners are optional for battery alerts.
- Accessibility is needed only for Keyboard Lock.
- Closed-lid work installs a one-time, narrow permission for VCG's exact `pmset` commands, with a Remove button shown after it is installed.

## Project

This is a native AppKit project generated from `project.yml` with XcodeGen.

```sh
xcodegen generate
open VibeCodingGuard.xcodeproj
```

## Build And Install

Run:

```sh
./build.sh
```

The build script uses a stable Apple Development signing identity when one is available. That keeps macOS privacy permissions, such as Accessibility for Keyboard Lock, attached to the same app across rebuilds.

The script installs the app to:

```text
~/Applications/Vibe Coding Guard.app
```

It also installs the launch agent at:

```text
~/Library/LaunchAgents/com.jpy.vibecodingguard.plist
```

## Safety

Closed-lid work mode is for a Mac sitting on a desk. Do not run long jobs with the Mac closed inside a bag.
