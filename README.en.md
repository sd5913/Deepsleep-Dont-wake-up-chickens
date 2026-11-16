# Night Coop · Egg Rush

[简体中文](README.md)

A pixel-art browser collection game with **4 maps × 4 rooms = 16 stages**. Collect as much as possible in each 60-second room and spend earned coins on upgrades. The current playtest exposes all 16 rooms immediately.

- **Manual collection:** left-click one reachable ground item to collect every unblocked ground item inside the player’s ring, without an upgrade; repeatedly click resource stations for individual items. Ground eggs are slightly larger, and clicks within 24 screen pixels select a nearby eligible egg. Assistance obeys player reach and cover; proximity never auto-collects. WASD/arrows move; Esc pauses. Audio is currently disabled.
- **Fair starts and patrols:** the first three seconds protect the player from hen sight, clucks, alert gains and capture. Hens start in all four quadrants and repeatedly shuffle global destinations, with navigation around cover and recovery from blocked routes.
- **Continuous supply:** ground eggs respawn in random batches. Nests show their actual 2–6 egg stock and refill after being emptied.
- **Chains:** collect within 2.2 seconds to keep a chain. Every 12 pickups increases the multiplier, up to four times. A broken chain never deducts earned points. Timeout settles the run, without a fixed target or exit requirement.
- **Four themed maps:** chickens/eggs, sheep/wool, squirrels/pinecones and dogs/cabbages. Finish four rooms to unlock the next map. All themes share spawning, collection and sight-cone patrol rules. They reuse the original four room layouts with a full-map view and no follow camera.
- **Golden hens:** stages 3–4 introduce one halfway through; stage 4 adds another later. Golden eggs have a base value of five points instead of one.
- **Permanent wallet, map-local buffs:** five points earn one coin. Coins survive changing maps, restarting maps and reloading. Gather radius, bonus yield and nest refill accumulate across a map’s four rooms; entering another map or restarting resets only buffs and that run. The menu allows buying buffs for the selected map before starting. One Start click plays its transition and launches the room directly.
- **Progress and transitions:** room records, map totals and unlocks are saved in this browser. One-second walking transitions consume no round time. Unsettled rooms restart after leaving. Legacy saves retain coins, buffs and the original first-map progress. Saves do not sync across devices.

## Run and check

Use **Godot 4.5.1 Standard** with matching export templates, Compatibility rendering and a 960×540 design viewport. Import `project.godot` and press F5. The entry scene is `scenes/arcade/game.tscn`; the original stealth scene remains at `game.tscn` for reference.

```bash
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script tests/arcade_flow.gd
godot --headless --path . --fixed-fps 60 --script tests/arcade_roaming.gd
godot --headless --path . --fixed-fps 60 --script tests/map_progression.gd
godot --headless --path . --export-release Web build/web/index.html
```

Serve Web exports over HTTP(S). Keep build output out of Git. `.codex/setup.sh` installs matching editor/templates for the cloud environment. Generated character/environment art follows the supplied references; font licenses are in `assets/fonts/`.

Hens retain the original occluded sight cones and obstacle-aware patrols, now at speed 82. Being seen raises alert; at 100 the farmer arrives from the north. Capture settles the current score early without unlocking the next stage. Base pickup radius is 70 world units, plus 4 per gather upgrade.

Pacing pass: stage one has four patrolling hens, followed by one additional ordinary hen per stage. The halved pickup diameter uses a soft, hollow pale-yellow halo instead of dashes. Reachable hovered targets highlight; up/down movement uses four-frame front/back runs, including during pickups. The final ten seconds receive a visual cue. Golden hens arrive at 30 seconds, with the second stage-four hen at 45 seconds.

Combo feedback follows the player rather than occupying the top HUD. Every fifth pickup triggers a short scaling pop, golden sparks and encouragement. Future scattered powerups are designed in [ITEM_DESIGN.md](ITEM_DESIGN.md); they are not implemented yet.

Snake eggs are implemented in chicken rooms 2–4. See [GAME_FRAMEWORK.md](GAME_FRAMEWORK.md) and [VISUAL_PLAN.md](VISUAL_PLAN.md).

Chicken room one has no snakes; rooms two, three and four randomly hide exactly 2, 3 and 4 snake eggs among their initial ground eggs. Only collection triggers them; there is no timed encounter schedule. A warning transition precedes those rooms. After a 1.5s pickup/enlarge/crack/hatch sequence and a frightened-player exclamation, snakes dash in one fixed direction, stop at cover/walls, and never home toward the player. Contact costs at most three score points, breaks the chain and grants 1.2s protection without ending the run or deducting coins.

New animal and resource art shares a pixel-grid shader with hard alpha and color steps. Garden stations use woven vegetable baskets; ground cabbages still sprout with soil particles. Growth is visual and never blocks collection. Net-displacement recovery fixes ordinary and golden animals jittering at crate corners.

`ArcadeGame.free_stage_select` defaults to true for testing. Set it to false for the original sequential progression. Map entry still resets buffs and keeps coins; picking another room within the same map keeps buffs. Additional regressions: `tests/snake_playtest.gd` and `tests/patrol_recovery.gd`.

Refinement: detection triggers a brief screen shake and large local exclamation, with a cooldown. Difficulty rises within each chapter; the next chapter opens above the previous opener and below its finale. Later patrols see farther and build alert faster. Animals no longer feed live positions to an active farmer. Farmer chase speed is 185–222.5 versus player speed 330. Every room requires alert 100. Three continuous seconds without sight ends pursuit; a leaving farmer cannot reacquire the player and a six-second departure grace prevents immediate replacement. Squirrel maps replace golden squirrels with randomly spawned golden pinecones. Sheep maps add hay and fences, squirrel maps pines and bushes, and gardens hedges and nursery borders. Shared collision footprints remain unchanged. Verify with `tests/harvest_refinement.gd`.

Regression `tests/collection_escape.gd` covers whole-ring pickup, reach/cover, one-click cross-map/replay starts, pre-start buying, alert 100, slower pursuit and a real three-second escape with pause/departure grace.

Patrol sight tuning: animals use 54–60° cones instead of 78°, with screen-space reach about 140–159 instead of 175–231. Late-room unobstructed cone area is reduced by roughly 64%. The visible cone and actual sight test share these smaller parameters; cover, alert 100 and farmer escape behavior remain active.

## Shared progress and playtest log

The shared log in [README.md](README.md) records the teacher's reviewed baseline (`1fa4359`), merged PRs #4/#5, known engineering evidence, next actions and owner placeholders. The current storage-notice change is based on `c1306ea`. Browser persistence, normal unlocks, blocked storage/private-window behavior, new-player comprehension and late-room readability are explicitly **pending**, with no invented results. This change performs build preparation only; no new gameplay or browser playtest is run.

Startup now distinguishes a missing save from denied reads and failed writes. A unique temporary key checks writability without touching the progress key. Unreadable or unrecognized saves stay protected from overwrite while the player continues temporarily. Menu and in-round notices explain the possible loss of temporary/new progress on refresh or close; a later successful write clears a write-failure notice. Private browsing does not automatically imply blocked storage. Record the exact commit, browser/version and window size when these cases are eventually tested.
