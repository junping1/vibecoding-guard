# Vibe Coding Guard

A tiny local macOS menu bar app for keeping long-running work alive while the display rests.

The main control is Keep Awake:

- Off: VCG does nothing until you turn it back on.
- Auto: turns on when Codex or Claude Code is active.
- Always: keeps the Mac awake until you turn it off.

It can also:

- Let the display sleep after idle time.
- Warn before the battery gets low.
- Enable closed-lid work mode after macOS admin approval.
- Block accidental keyboard input with Keyboard Lock while Keep Awake is active.

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
