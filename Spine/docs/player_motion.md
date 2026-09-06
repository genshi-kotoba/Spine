# Player Motion Contract

## Shared Contract

`res://scenes/player.tscn` owns the project's default movement setup. It references the single shared resource at `res://scripts/player/default_player_motion.tres`, so a new layer gets the same horizontal feel by instancing `player.tscn` without copying numbers into the level scene.

The public tuning unit is time, not acceleration:

| Field | Default | Meaning |
| --- | ---: | --- |
| `max_speed` | `400 px/s` | Horizontal speed at full input. |
| `start_to_max_time` | `0.18 s` | Rest to full speed. |
| `reverse_to_max_time` | `0.14 s` | Full speed in one direction to full speed in the other. |
| `stop_to_rest_time` | `0.12 s` | Full speed to rest after releasing input. |
| `gravity` | `980 px/s²` | Existing vertical gravity; no jump behavior is added. |

The profile converts each time to a rate internally. It also preserves reverse state while velocity crosses zero; otherwise a reverse would begin fast and fall back to slow startup halfway through.

When `StoryMonitor.input_locked` is active, `Player` clears both velocity and transition state. A scene or cutscene can therefore unlock input without carrying a stale reverse acceleration into the next step.

## Research Basis

- Celeste's public player implementation defines separate `MaxRun`, `RunAccel`, and `RunReduce`, then approaches target horizontal speed every frame instead of applying one universal acceleration. Reference: [Player.cs at commit `1b0ce45c`](https://github.com/NoelFB/Celeste/blob/1b0ce45c75e05649ae91b44a8bb6b196684e4352/Source/Player/Player.cs#L30-L33) and its [horizontal motion update](https://github.com/NoelFB/Celeste/blob/1b0ce45c75e05649ae91b44a8bb6b196684e4352/Source/Player/Player.cs#L2879-L2895).
- This project currently has no jump input or jump state. Coyote time, jump buffering, variable jump height, and air control are therefore intentionally outside this change. They belong in a future jump module rather than in the horizontal movement contract.

## Layer Workflow

1. Instance `res://scenes/player.tscn`; do not copy `move_speed`, `acceleration`, or `ground_friction` into the layer.
2. For a global feel adjustment, edit `default_player_motion.tres` once and validate the C3 flow.
3. For a deliberate one-off layer, duplicate the `.tres`, assign it to that layer's `Player.motion_profile`, and document why it differs.
4. The old `move_speed`, `acceleration`, `ground_friction`, and `gravity` exports remain only as a fallback for hand-built legacy Player nodes without a profile. New content must use `motion_profile`.

## Acceptance

```sh
/Volumes/OmubotDisk/Godot/Godot.app/Contents/MacOS/Godot \
  --headless --path /Volumes/OmubotDisk/Godot/Spine/Spine \
  --scene res://scenes/player_motion_test.tscn
```

The test runs the real Player using deterministic `0.01s` steps and asserts the default start, stop, and reverse times. Follow it with the C3 scene self-check before merging.

## Rollback

Revert the commit that adds `PlayerMotionProfile.gd`, `default_player_motion.tres`, and the `player.tscn` resource binding. The legacy Player exports preserve the prior `move_toward` behavior for a targeted rollback.
