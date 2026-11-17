# Agentic prompt: swap the little prince for Pumpkin Duke

Copy everything below the line into your coding agent. It is written
against the real project layout, so run it from the repo root.

---

You are working in a Godot 4.7.2 3D project
(`/home/putzwirk/Documents/GodotGameDev/your-personal-planet`,
`project.godot` at the root, run from that directory).

## Goal

Replace the little prince character visual with the Pumpkin Duke model,
with a verlet-simulated cape, procedural IK legs that track the body,
and a vertical jiggle on the body while moving. Gameplay code must not
change behavior; only the visual layer changes.

## Current architecture (do not redesign this)

- `scenes/player.tscn`: `CharacterBody3D` (script `scripts/game/player.gd`,
  `class_name Boy`) with a child `Visual: Node3D` (scale 0.75, unique name
  `%Visual`) scripted by `scripts/game/prince_model.gd`
  (`class_name PrinceModel`).
- The model script preloads the mesh at its line 4:
  `const MODEL_SCENE: PackedScene = preload("res://assets/models/little_prince.glb")`.
- `player.gd` drives the visual ONLY through this API — keep every method
  working with the same signatures: `set_motion(speed_ratio, grounded,
  running, velocity_len)`, `set_sitting(bool)`, `set_cold(amount)`,
  `play_jump()`, `play_land_squash(strength)`, `play_land_dust()`,
  `play_catch_pose()`, `play_net_swing()`, `is_net_active()`,
  `get_net_catch_point()`. It also reads the `landed(strength)` and
  `jumped` signals, which you must keep emitting.
- Cape physics already exists as `scripts/game/prince_cape.gd`
  (`class_name PrinceCape`): verlet chains over `Skeleton3D` bones named
  `cape_L_01`, `cape_M_01`, `cape_R_01` with 4 bones each, fed by
  `setup(skeleton)`. Reuse this approach for the duke's cape instead of
  inventing a new simulator.

## The new model

- Source file: `/home/putzwirk/Documents/blender/pumpkin_duke/pumpkin_duke.glb`.
  Copy it to `assets/models/pumpkin_duke.glb` (replacing the prince file
  in the load path, not deleting shared code) and let Godot import it.
- The GLB is ~1.7 units tall, Y-up, and contains ~34 plain meshes under
  one root with NO skeleton/armature: pumpkin head shell (hollow, real
  cut-out eyes/nose/mouth), inner glow surfaces, stem, leaves, vine
  collar + tendrils, purple cloak (UV texture embedded), gold clasp star,
  two clawed arms, two thin legs. There are no bones and no animations.

## Tasks

1. **Import and swap.** Get `pumpkin_duke.glb` into `assets/models/`,
   instance it in place of `little_prince.glb` in the model script, and
   rescale/reposition so the duke's feet sit at the `Visual` origin and
   its total height roughly matches the old capsule
   (`CapsuleShape3D` radius 0.165, height 1.125 in `player.tscn`; adjust
   the capsule only if the duke clearly over/underfills it).
2. **Rig.** Add a `Skeleton3D` (built in code or as a scene, your choice)
   with at least: a `body` root bone, one head bone, three cape chains
   (`cape_L_01`, `cape_M_01`, `cape_R_01`, 4 bones each, running from the
   collar down the cloak), and two 2-bone leg chains (hip -> tip).
   Bind or attach every duke mesh to the rig so nothing stays behind when
   bones move. The cloak is a single-piece mesh: give it skin weights (or
   equivalent segmentation) along its length so chain rotation bends it
   instead of swinging it rigidly.
3. **Cape IK.** Hook the cape chains into the existing `PrinceCape`
   verlet simulation (`setup(skeleton)` + its per-frame `_process`).
   Tune gravity/damping so the cloak trails and sways while walking and
   settles at rest. Do not rewrite the integrator unless it cannot handle
   the new rest pose.
4. **Leg IK.** The duke's legs are static spikes in the GLB. Drive the
   two leg chains procedurally so the feet track the ground under the
   moving body: plant each foot, lift/step it as the body travels (use the
   velocity already passed to `set_motion`), keep both feet grounded at
   idle. Legs must follow the pumpkin when it moves, turns, and lands.
5. **Body jiggle.** Add a vertical spring on the `Visual` node (position
   offset and/or squash scale, small amplitude): bob continuously scaled
   by speed while moving, plus a one-shot squash-and-recover driven by
   the existing `landed(strength)` signal (reuse the
   `play_land_squash(strength)` path). Never move the `CharacterBody3D`
   itself; visuals only.
6. **Keep the game intact.** Net/catch poses, sitting, cold overlay, and
   all `PrinceModel` methods listed above must keep working (stub the
   duke equivalents where a prince-only prop has no counterpart, e.g.
   map the net anchors onto a claw/hand bone). No changes to gameplay
   scripts outside the model/cape visual scripts unless the scene tree
   requires it.

## Acceptance criteria

- `godot --headless --check-only` (or the repo's `scripts/check.sh`) passes.
- Entering play mode shows Pumpkin Duke instead of the prince, feet on
  the ground, correctly scaled against the planet.
- Walking/running: cape trails and sways, legs step and stay planted
  between steps, body bobs with speed.
- Jumping/landing: body squashes on land proportional to `strength`,
  legs bend, cape lifts.
- Idle: everything settles, no jitter, no console errors.
