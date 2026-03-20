# Paint Walls Grow — Roblox Game Template

A Roblox boilerplate built with [Rojo](https://rojo.space). Players paint walls to grow bigger, return to their base to refill paint, hit size milestones to earn coins, and spend coins on upgrades.

## Gameplay Loop

1. Spawn at your personal base pad.
2. Walk to the shared wall arena.
3. **Hold left mouse button** (or tap on mobile) to paint nearby walls.
4. Painting spends paint from your bucket and grows your character.
5. Return to your base pad to automatically refill paint.
6. Reach size milestones to earn coins.
7. Open the **Shop** (yellow button, bottom-right) to buy upgrades.

## Upgrades

| Upgrade | Effect |
|---|---|
| Bigger Max Size | Increases the maximum size cap |
| Size Multiplier | Multiplies paint-to-size conversion |
| Bigger Brush | Increases brush radius |
| Faster Brush | Reduces brush cooldown |
| More Bucket Paint | Increases paint capacity |

## Project Structure

```
roblox-game-template/
├── default.project.json          # Rojo project file
├── docs/
│   └── PRD.md                    # Product requirements document
└── src/
    ├── ReplicatedStorage/
    │   └── Shared/
    │       ├── Config.lua             # All tunable values
    │       ├── UpgradeDefinitions.lua # Upgrade costs/levels
    │       └── PlayerStats.lua        # Per-player stat object
    ├── ServerScriptService/
    │   ├── GameManager.server.lua     # Bootstrap + remote handling
    │   ├── WorldBuilder.lua           # Arena + base generation
    │   ├── PaintService.lua           # Wall painting logic
    │   ├── GrowthService.lua          # Size growth + milestones
    │   ├── RefillService.lua          # Base refill logic
    │   └── UpgradeService.lua         # Upgrade purchase logic
    └── StarterPlayer/
        └── StarterPlayerScripts/
            ├── PaintController.client.lua  # Input + brush firing
            ├── HUD.client.lua              # Stats panel + milestone popup
            └── ShopUI.client.lua           # Upgrade shop UI
```

## Setup

### Requirements

- [Rojo](https://rojo.space) 7.x
- Roblox Studio

### Steps

```bash
# Install Rojo if needed
aftman install   # or: cargo install rojo

# From the project root
rojo serve
```

Then in Roblox Studio:

1. Open the **Rojo** plugin.
2. Click **Connect** (default port 34872).
3. Press **Play** to test locally.

## Tuning

All gameplay values are in `src/ReplicatedStorage/Shared/Config.lua`:

- `SizePerPaintUnit` — how much size is gained per wall painted
- `BrushRadiusBase` — default brush reach
- `BrushCooldownBase` — seconds between brush ticks
- `PaintCapacityBase` — starting bucket size
- `SizeCapBase` — base maximum player size
- `Milestones` — size thresholds and coin rewards
- `UpgradeStepValues` — the per-level bonus for each upgrade

Upgrade costs and max levels are in `src/ReplicatedStorage/Shared/UpgradeDefinitions.lua`.

## Architecture Notes

- **Server-authoritative**: all paint actions, growth, refills, and purchases are validated server-side.
- **RemoteEvents/Functions** managed by `GameManager.server.lua`:
  - `Paint` — client fires with brush world position
  - `StatsSync` — server pushes serialized stats to client
  - `MilestoneReached` — server fires on milestone unlock
  - `Feedback` — general feedback event
  - `BuyUpgrade` — RemoteFunction for shop purchases
- **Client** only handles input and UI rendering; no gameplay authority.
- All shared state lives in `PlayerStats` objects keyed by `UserId`.

## Extending

| Feature | Where to start |
|---|---|
| Data persistence | Wrap `playerStates` in a DataStore save/load in `GameManager` |
| Rebirths | Reset size + upgrades, award rebirth multiplier in `Config` |
| Leaderboard | Read `PaintService.GetPlayerWallCount()` and publish to `DataStoreService` |
| VFX on paint | Add a `ParticleEmitter` in `PaintController` on brush tick |
| New upgrades | Add entry to `UpgradeDefinitions`, add step value to `Config`, add handler to `PlayerStats` |
| More paint colors | Append to `Config.PaintColors` |
