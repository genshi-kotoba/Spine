# C3 Breath Bubble FX

## Scope

The C3 `Bubble` is a reusable world-space breath vessel. Its liquid height is the remaining `BreathSystem` countdown: full after a short breath, falling continuously across `breathe_timeout`, and empty at hypoxia.

- Inertia: a damped spring follows the player with a small vertical bob instead of sticking to a fixed offset.
- Burst: capacity exhaustion freezes the vessel in place, expands a CC0 ring, emits procedural blue droplets, and invokes the shared `ScreenShake` for `0.18s`.
- Recovery: `breathe()` and disabled-breath cleanup restore the vessel with a `0.32s` liquid refill plus a small elastic scale return; the live countdown updates the refill target without cancelling it. A special-point pass retains its existing timer-only reset.
- Rocking: persistent hypoxia/hold rocking is a bounded, damped angular spring. It alternates sides at `0.42s` intervals with constrained random force, preserving a light seesaw inertia instead of hard constant-speed direction changes.
- Ownership: `Corridor`, `BreathSystem`, and short burst effects share the scene-owned `Effects/ScreenShake`; no secondary `Camera2D` rotation writer is created during a hold.

## Asset And License

- `assets/fx/bubble_pop_ring.png` is Kenney Particle Pack 1.1 `circle_03.png`, CC0 1.0.
- Provenance and SHA-256 are recorded in `docs/CREDITS.md`.
- No animation package or generated-cache files are included; the timing and droplets are code-driven.

## Acceptance

Run from the repository root:

```sh
/Volumes/OmubotDisk/Godot/Godot.app/Contents/MacOS/Godot \
  --headless --path /Volumes/OmubotDisk/Godot/Spine/Spine \
  --scene res://scenes/c3_level.tscn -- --corridor-breath-self-check
```

The check asserts liquid capacity, inertial follow, recovery state, pop state, pop shake, existing hypoxia behavior, and corridor compatibility. `git diff --check` verifies the tracked changes. Visual MCP/manual playthrough remains required for art-direction acceptance.

## Rollback

Revert the commit that introduces this document and these files. This removes only the bubble effect, its CC0 ring, and its acceptance record; it leaves the existing breath state machine intact.
