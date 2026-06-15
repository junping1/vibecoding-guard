# Vibe Coding Guard

A tiny local macOS menu bar app for keeping long-running work alive while the display rests.

It can:

- Keep the Mac awake for long Codex sessions, builds, downloads, and remote work.
- Turn on automatically when local Codex or Claude agent work is detected.
- Let the display sleep after idle time.
- Warn before the battery gets low.
- Enable closed-lid work mode after macOS admin approval.
- Block accidental keyboard input with Pet Lock while Guard is on.

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
