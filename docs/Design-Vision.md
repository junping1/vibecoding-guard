# Design Vision

_A north star for what this app wants to become. Not a spec — a point of view._

---

## The one sentence

> **Walk away. It's handled.**

That is the whole product. Not "keep awake modes." Not "power management."
The feeling of trusting your Mac to finish the work while you go live your life.

Every decision in this document serves that one feeling. Anything that doesn't
gets cut.

---

## The philosophy

There are two ways to build a utility like this.

**The control panel.** Give the user every knob — modes, thresholds, tabs,
permissions — and call it "powerful." This is the easy path. It ships the
product's hard decisions to the user disguised as flexibility.

**The trusted assistant.** Make the hard decisions *for* the user, make them
right, and disappear. This is harder to build and infinitely better to use.

We choose the second. The intelligence is the product. If we ever ask the user
to configure something the app could have figured out, we have failed.

> Simplicity here is not "fewer features." It is **fewer decisions handed to the
> user.** The app should carry the complexity so the person doesn't have to.

---

## What we say no to

Saying no is the work. These are deliberate, defended cuts.

### No mode selector (Off / Auto / Always)
Three modes exist only because the app doesn't trust its own detection.
- *Always* wastes power keeping a Mac awake while nothing is running.
- *Off* is just "quit the app."
- *Auto* is the only honest behavior.

So there is **one behavior**: stay awake exactly while Codex or Claude Code is
working; sleep the instant they stop. No radios. No choice. The user never picks
a mode because there is nothing to pick — it already knows.

### No settings window
A tabbed preferences window is a confession that the defaults are wrong. We will
make the defaults right and delete the window. Battery thresholds, idle-sleep
minutes, critical-percent dropdowns — these are knobs for problems the app should
solve silently. Choose the right values. Ship those.

### No warning labels
A feature that ships with *"never put it in a bag or your Mac could overheat"* is
not finished. A warning label is a design failure made visible — a physical risk
offloaded onto the user's memory. We do not ship a sharp edge with a sign taped
to it. We **sense the danger instead of warning about it** (see below).

### No cockpit on the dashboard
Power users will want Always mode, custom thresholds, a settings panel. We serve
them through **intelligence plus a single escape hatch** (an Option-click advanced
sheet, or a plain config file) — never by putting the controls where the other
95% have to see them.

---

## The walk-away gestures (the hero, not the extras)

Lid-close and keyboard-lock are not side features to hide. They are the most
literal expression of the promise. A laptop user's natural "I'm done here" motion
is to **shut the lid and leave** — and the most fragile moment of a long run is
when a pet, a child, or a sleeve lands on the keys. If the app honors those two
realities, it delivers the whole product.

The mistake is never the capability. It is the configuration wrapped around it.
So we keep the power and delete the cockpit:

> **Cut the knobs, not the capability.** A killer feature earns the main stage by
> becoming a *gesture with zero configuration and zero warning labels* — never a
> tab with a toggle.

### Keep working with the lid closed
- **The gesture is the interface.** You close the lid while an agent runs; the
  work keeps going. There is no "lid-closed mode" toggle to find.
- **Permission is a one-time, in-context, benefit-framed ask** at the exact
  moment you first close the lid with work running — *"Keep this running with the
  lid closed? One-time OK."* Reversible, then invisible forever. Never a setup
  step buried in a tab.
- **Safety is sensed, not signed.** Instead of "never in a bag," the app watches
  temperature: if heat climbs while lidded, it backs off — eases up, alerts, or
  lets the Mac sleep before damage. The scariest part of the feature becomes a
  reason to trust it.

### Guard the session while you're away
- **One deliberate gesture, one obvious exit.** Locking input is intentional, and
  the way out is shown the instant it locks (a clear "press ⌘⌥⌃L to unlock"), so
  no one is ever trapped.
- **It protects the run, and it says so.** Reframed away from the cute internal
  "pet lock" name toward what it means: keeping an unattended session safe from
  accidental input.
- **Permission asked once, in context, as a benefit** — never a checkbox the user
  has to understand before the feature makes sense.

## The reframe: the menu bar *is* the app

There is no main window. The entire experience lives in one calm popover.

```
   ◐  Claude Code is working
      Your Mac will stay awake.
      ─────────────────────────────
      Running 2h 14m · on power
```

- **The icon breathes.** A slow, calm pulse while an agent is alive; at rest when
  idle. You feel the state without reading a word. All day, the menu bar quietly
  reassures you.
- **One glance answers the only two questions anyone has:** Is it watching? Is
  anything wrong?
- **No "Customize."** If something needs attention — on battery, power low — the
  popover says so in one human sentence and offers exactly **one** action. Never
  a tab. Never a dropdown.

---

## The details worth obsessing over

**Name and metaphor.** "Guard" and a shield are defensive and anxious — security
framing for what is really about *flow and trust*. The emotion we want is calm
confidence. The mark should read as "watching over your work," not "firewall."

**Zero setup.** It works the millisecond it launches. Permissions are requested
only at the exact moment a feature needs them, and always framed as a benefit:
*"So I can warn you before the battery dies — sound only, nothing to configure."*

**Human copy.** Not `Keep Awake: Auto` but *"Claude Code is working — I've got
this."* The app speaks like a competent assistant, not a control panel.

**Invisible correctness.** The low-battery warning fires at the *right* moment
because the app reasons about charge rate and time remaining — not because the
user set 20%. They never see the cleverness. They just never get burned.

**Sense the danger; don't warn about it.** Anywhere we are tempted to write a
caution, ask whether the app could *detect and handle* the condition instead.
Thermal back-off replaces "never in a bag." Smart battery timing replaces a
threshold dropdown. Intelligence, not instructions.

---

## The north-star moment

> You kick off a long agent run. Out of habit you close the lid and walk to
> lunch. It keeps going. You come back; the work is done. You never opened the
> app, never picked a mode, never read a warning.
>
> You forgot the app exists — which is exactly why you trust it.

That is the bar. The best utility is the one you stop noticing.

---

## Principles to decide by

When a future change is unclear, ask in order:

1. **Does it serve "walk away, it's handled"?** If not, cut it.
2. **Can the app decide this instead of the user?** If yes, it must.
3. **Would this need a warning label or an explanation?** Then it isn't done —
   sense and handle the condition instead.
4. **Is this a knob, or a gesture?** Prefer the gesture. Cut knobs, not power.
5. **Does it belong on the main surface, or backstage?** Default to backstage.
6. **Does it make the person feel calmer, or busier?** Only ship calmer.

---

_This is the direction, not the diff. Implementation can stage toward it — but
every step should move the app closer to disappearing._
