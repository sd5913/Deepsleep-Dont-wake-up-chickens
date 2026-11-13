# Night Coop · Egg Rush

[简体中文](README.md)

A pixel-art browser collection game. Gather as many eggs as possible in **60 seconds**, spend earned coins on upgrades, and unlock bigger, denser stages.

- **Manual collection:** left-click reachable eggs or repeatedly left-click an open straw nest. Ground eggs are slightly larger, and clicks within 24 screen pixels select a nearby eligible egg. Assistance obeys player reach and cover; proximity never auto-collects. WASD/arrows move; Esc pauses. Audio is currently disabled.
- **Fair starts and patrols:** the first three seconds protect the player from hen sight, clucks, alert gains and capture. Hens start in all four quadrants and repeatedly shuffle global destinations, with navigation around cover and recovery from blocked routes.
- **Continuous supply:** ground eggs respawn in random batches. Nests show their actual 2–6 egg stock and refill after being emptied.
- **Chains:** collect within 2.2 seconds to keep a chain. Every 12 pickups increases the multiplier, up to four times. A broken chain never deducts earned points. Timeout settles the run, without a fixed target or exit requirement.
- **Four stages:** finish a run to unlock the next. World dimensions scale by 1, 1.2, 1.4 and 1.6; cover, nests and ground eggs become denser. The camera zooms uniformly while eggs retain a minimum clickable size.
- **Golden hens:** stages 3–4 introduce one halfway through; stage 4 adds another later. Golden eggs have a base value of five points instead of one.
- **Persistent growth:** five points earn one coin. Upgrade gather radius, bonus egg chance and nest refill, each up to five levels. High scores are independent from currency. Progress is stored in the current browser, without cross-device synchronization.

## Run and check

Use **Godot 4.5.1 Standard** with matching export templates, Compatibility rendering and a 960×540 design viewport. Import `project.godot` and press F5. The entry scene is `scenes/arcade/game.tscn`; the original stealth scene remains at `game.tscn` for reference.

```bash
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script tests/arcade_flow.gd
godot --headless --path . --export-release Web build/web/index.html
```

Serve Web exports over HTTP(S). Keep build output out of Git. `.codex/setup.sh` installs matching editor/templates for the cloud environment. Generated character/environment art follows the supplied references; font licenses are in `assets/fonts/`.

Hens retain the original occluded sight cones and obstacle-aware patrols, now at speed 82. Being seen raises alert; at 60 the farmer arrives from the north. Capture settles the current score early without unlocking the next stage. Base pickup radius is 70 world units, plus 4 per gather upgrade.

Pacing pass: stage one has four patrolling hens, followed by one additional ordinary hen per stage. The halved pickup diameter uses a soft, hollow pale-yellow halo instead of dashes. Reachable hovered targets highlight; up/down movement uses four-frame front/back runs, including during pickups. The final ten seconds receive a visual cue. Golden hens arrive at 30 seconds, with the second stage-four hen at 45 seconds.

Combo feedback follows the player rather than occupying the top HUD. Every fifth pickup triggers a short scaling pop, golden sparks and encouragement. Future scattered powerups are designed in [ITEM_DESIGN.md](ITEM_DESIGN.md); they are not implemented yet.
