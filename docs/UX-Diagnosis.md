# Vibe Coding Guard — UX Diagnosis (User's Perspective)

_Analysis date: 2026-06-15. Scope: affordance, clarity, readiness, discoverability._

## 0. What the app actually is

A menu-bar utility that keeps a Mac awake while long-running coding agents
(Codex / Claude Code) work. Everything else (lid-closed mode, display sleep,
battery alerts, keyboard lock) exists to make "leave a long run unattended"
safe. **The whole product is one job: "don't let my Mac sleep while my agent
is working."**

Two surfaces:

- **Menu-bar dropdown** (`MenuController`) — status lines + quick actions.
- **Control Center window** (`ControlCenterView`, 560×400) — a hero status row,
  3 mode radios (Off / Auto / Always), and a 4-tab "Customize" segmented panel
  (Keep Awake / Display / Battery / Keyboard).

The engineering is clean. The problems are almost all about **communication**:
naming, where things live, and whether the user can tell what state they're in
and what will happen next.

---

## 1. High-impact issues (confuses the core task)

### H1 — "Auto" never explains *what* it watches for, *where the decision lives*
The single most important control is the Off / Auto / Always mode. "Auto" is the
default, but the radio group gives no hint that Auto = "wake while Codex/Claude
Code is running." That explanation (`Watches for: Codex and Claude Code`) is
hidden inside Customize ▸ Keep Awake — a tab most users won't open.
- **Effect:** a first-run user picks "Auto" and has no idea what triggers it, or
  why their Mac sometimes sleeps (no agent detected) and sometimes doesn't.
- **Fix:** put a one-line description directly under each mode, or under the
  radio row, e.g. *"Auto — stays awake only while Codex or Claude Code is
  running."* Make the trigger visible at the point of decision.

### H2 — "Keep Awake" is the name of two different things in the same window
The top radios choose the **mode**. The Customize panel's first tab is *also*
called **"Keep Awake."** Same words, two scopes, stacked vertically. Users can't
tell whether the tab re-controls the mode or configures something else.
- **Fix:** rename the tab (e.g. **"Agents"** or **"Detection"**) so the mode
  selector owns "Keep Awake" and the tab owns its actual content (what it
  watches for + lid-closed).

### H3 — "Show Window" and "Customize…" are two menu items that do the identical thing
Both call `showControlCenter(onboarding:false)`. Two labels, one behavior — users
will click both expecting different destinations.
- **Fix:** keep one ("Settings…" or "Open Vibe Coding Guard"). If you want
  "Customize…" to mean something, have it deep-link to the Customize panel /
  a specific tab.

### H4 — The "one-time approval" nag can fire when the user never asked for lid-closed mode
`needsSetupHelp` = keepAwake running **and** (`batterySleepMinutes != 0` OR
lid-mode-on-but-not-applied). Because of the first clause, the hero can show
*"macOS needs a one-time approval for lid-closed mode"* and the password-setup
hint even for someone who only wants plain lid-open keep-awake on battery.
- **Effect:** the app appears to demand an admin password for a feature the user
  didn't enable — a trust-eroding moment for a utility that touches `sudoers`.
- **Fix:** only surface lid-closed setup when `lidClosedModeEnabled` is on.
  Separate "battery will sleep" guidance from "lid-closed needs approval."

### H5 — Keyboard Lock silently does nothing unless Keep Awake is also running
Keyboard Lock only blocks keys while Keep Awake is active (`waits for Keep
Awake`). A user can flip the switch (and grant Accessibility) with mode = Off and
see no effect, with only a small grey info line explaining the dependency.
- **Fix:** make the dependency explicit at toggle time — disable/annotate the
  switch when mode is Off ("Starts when Keep Awake turns on"), or offer to turn
  Keep Awake on. Don't let a toggle look active while it's inert.

### H6 — First run is called "Set Up…" but there is no setup
`onboarding:true` only changes the window *title*; the user is dropped into the
full dense settings panel with no walkthrough, no recommended path, no "Done."
Closing the window silently marks onboarding complete.
- **Fix:** a real 2–3 step first-run (what it does → pick a mode → optional
  extras), or at minimum a one-paragraph "Here's how this works" header on first
  launch with a primary "Start" button.

---

## 2. Medium-impact issues (friction, ambiguity)

### M1 — The menu-bar presence is cryptic
The status item shows a shield icon **plus the text "Auto" / "Off" / "Always."**
Out of context, a lone "Auto" in the menu bar means nothing, and the icon
vocabulary (shield / shield.fill / sparkles / bolt / shield.slash / warning
triangle) has no legend. The tooltip helps, but only on hover.
- **Fix:** consider icon-only with state by fill/symbol, and move the word into
  the dropdown header (which already has it). If you keep text, make it
  self-describing ("Awake: Auto").

### M2 — Mode-switching from the menu is buried in a submenu
Changing Off/Auto/Always — the most common action — requires opening the "Keep
Awake" submenu. The three modes are short; they could be inline radio items at
the top of the menu (one fewer click, full visibility of current state).

### M3 — Resizable window that can't really resize
The window is `.resizable` (min 520×360) but all content is pinned to 500/464 px
and centered. Dragging the edge just grows empty margins — a false affordance.
- **Fix:** drop `.resizable`, or make content actually reflow.

### M4 — "Notification banners" button has a contradictory authorized state
When notifications are authorized, the button reads "Allowed" **and is disabled**,
but the handler's authorized branch tries to fire a test alert (dead path). The
user gets no way to re-test or to learn banners are on beyond a greyed label.
- **Fix:** when authorized, either show a subtle "On ✓" status (not a dead
  button) or repurpose the button to "Send test" (which already exists
  separately, so just drop the dead branch).

### M5 — Lid-closed cancel has no explanation
If the user cancels the admin-password prompt, the switch correctly snaps back
off — but with no message saying *why*. Looks like a bug ("I toggled it and it
turned itself off").
- **Fix:** on cancel/failure, show a brief inline note: "Lid-closed mode needs
  admin approval — not enabled."

### M6 — Two thresholds that silently rewrite each other
Setting Warning ≤ Critical (or vice-versa) auto-adjusts the *other* popup
(`changeWarningLevel` / `changeCriticalLevel`). The other dropdown's value
changes with no indication the app moved it.
- **Fix:** when auto-adjusting, briefly flash/annotate the changed field, or
  constrain the second popup's options so an invalid pair can't be chosen.

### M7 — Verb/noun naming drift for the same feature
"Lock Keyboard" (switch), "Keyboard Lock" (summaries/menu), tab "Keyboard",
internal "Pet Lock." Pick one user-facing name and use it everywhere
("Keyboard Lock").

---

## 3. Low-impact / polish

- **L1 — Icon legend:** the hero badge symbol changes meaning with no key; the
  subtitle carries the real message. Fine, but a consistent icon↔state mapping
  documented in tooltips would help.
- **L2 — Destructive-ish actions lack confirmation context:** "Sleep display
  now" fires immediately. Acceptable, but a momentary toast ("Display sleeping…
  work still running") reinforces the core promise.
- **L3 — Locked-keyboard escape hatch is invisible once locked:** the unlock
  shortcut ⌘⌥⌃L is only shown in settings text. Show it in a notification at the
  moment the keyboard locks, so a panicked user can read it.
- **L4 — "Power adapter not connected" appears in 3 places** (hero, menu line,
  tooltip) with slightly different wording. Consolidate phrasing.
- **L5 — No About / version / help.** A utility that edits `sudoers` benefits
  from a visible "what this changes / version" affordance for trust.

---

## 4. What's already good (keep it)

- Plain-language copy in most detail lines ("your work keeps running", "never in
  a bag, or your Mac could overheat").
- Permission requests are lazy and scoped (only when a feature needs them).
- The "Remove" button for the sudoers permission is exactly the right reversible
  affordance.
- Tone-colored status (green/orange/blue) gives quick at-a-glance health.

---

## 5. Suggested information architecture (target)

```
Menu bar:  [icon only, state by symbol]
  ┌ Auto · Claude Code detected · keeping awake     (status header)
  ├ ─────────────
  ├ ○ Off   ◉ Auto   ○ Always                       (inline, no submenu)
  ├ ─────────────
  ├ Keyboard Lock                            [✓]
  ├ Sleep Display Now
  ├ Settings…                                       (one entry, not two)
  ├ ─────────────
  └ Quit

Window:
  HERO:  big state line + one-sentence "what's happening now"
  MODE:  Off / Auto / Always  —  each with a one-line description inline
  TABS:  Agents · Display · Battery · Keyboard      ("Agents" not "Keep Awake")
```

---

## 6. Recommended order of work

1. **Quick clarity wins (low risk):** H2 rename tab, H3 merge menu items,
   M2 inline modes, M3 fix resize, M7 naming, H1 inline mode descriptions.
2. **Trust/correctness:** H4 scope the lid-closed nag, M5 cancel feedback,
   M4 notification button state.
3. **Onboarding:** H6 real first-run.
4. **Polish:** L1–L5.

Items in group 1 are mostly string/layout changes and deliver the biggest
clarity gain per effort.
