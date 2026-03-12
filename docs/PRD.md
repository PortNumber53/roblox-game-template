# Paint Walls Grow Game Template PRD

## Overview

This project is a Roblox game boilerplate centered around a simple progression loop:

1. Players leave their base with a limited bucket of paint.
2. They paint neutral walls in the arena.
3. Painting walls makes the player grow in size.
4. When paint runs low or empty, players return to their base to refill.
5. Reaching size milestones grants claimable coins.
6. Coins are spent on upgrades that improve painting efficiency and long-term growth.

The goal of this template is to provide a strong starting point for an arcade progression game that is easy to expand with persistence, multiplayer competition, cosmetics, pets, rebirths, and monetization later.

## Product Goals

- Provide a complete core loop that is immediately playable.
- Keep the code modular so the project can grow into a full simulator or tycoon-style game.
- Make progression feel satisfying within the first few minutes of play.
- Support local testing in Roblox Studio with clear systems and tunable values.

## Core Fantasy

The player should feel like:

- They are rapidly covering the world in paint.
- Their character becomes physically larger as they succeed.
- Returning to base is a strategic refill action, not just downtime.
- Milestones create moments of reward and anticipation.
- Upgrades create visible, meaningful changes to gameplay.

## Target Experience

### Session Feel

- Fast and easy to understand.
- Immediate feedback when painting.
- A short loop of paint, grow, refill, reward, upgrade, repeat.
- Clear visual ownership of progress through wall color changes and player size.

### Intended Audience

- Players who enjoy simulator-style progression games.
- Roblox players looking for satisfying upgrade loops.
- Developers who want a reusable starter template for territory-painting or growth-based games.

## Core Gameplay Loop

### Primary Loop

1. Spawn at a personal base.
2. Walk to the shared wall area.
3. Use a brush action to paint nearby wall sections.
4. Spend paint from the bucket for each brush action.
5. Gain size based on the amount of wall painted.
6. Reach a size milestone and claim or receive coin rewards.
7. Return to base to refill paint.
8. Spend coins on upgrades.
9. Repeat with better stats and faster progression.

### Secondary Loop

- Upgrade paint capacity to stay in the field longer.
- Upgrade brush size and speed to paint more efficiently.
- Upgrade max size and size multiplier to keep scaling progression.
- Push toward higher milestone tiers for larger coin payouts.

## Core Systems

## 1. Painting System

### Description

Players can paint valid wall surfaces while they have paint remaining in their bucket.

### Requirements

- Walls begin in a neutral color.
- Brush actions affect walls within a radius.
- Painting changes wall appearance to the player’s assigned paint color.
- Each paint action consumes paint from the player bucket.
- Painting should only affect tagged or designated paintable wall parts.
- The system should be tunable for brush size, paint cost, and action rate.

### Boilerplate Scope

- Basic area-based painting.
- Shared paintable walls in a simple arena layout.
- Server-authoritative paint handling.
- Immediate visual feedback on successful paint actions.

## 2. Growth System

### Description

As players paint walls, they gain size.

### Requirements

- Size increases incrementally based on paint applied.
- Size should visibly affect the character.
- Growth must respect a current maximum size cap.
- Upgrades can increase the cap and the rate of growth.

### Boilerplate Scope

- Character scaling tied directly to paint progress.
- Tunable size-per-paint ratio.
- Configurable base max size and upgrade-driven expansion.

## 3. Base Refill System

### Description

Each player has a personal base where they can refill their paint bucket.

### Requirements

- Every player gets an assigned base area.
- Standing in or interacting with the base refills paint.
- Refill should be clear and reliable.
- Paint capacity should be upgradeable.

### Boilerplate Scope

- Automatic refill when standing on the base refill pad.
- Simple visual identity for each player base.
- Server-side paint refill logic.

## 4. Milestone Reward System

### Description

Players earn coins when reaching milestone sizes.

### Requirements

- Milestones are predefined size thresholds.
- Each milestone should grant a reward once.
- Reward values should scale upward with later milestones.
- UI should show progress toward the next milestone.

### Boilerplate Scope

- Static milestone table.
- One-time coin awards per milestone.
- Display of current size, next milestone, and earned coins.

## 5. Currency System

### Description

Coins are the soft currency used for upgrades.

### Requirements

- Players earn coins from milestone rewards.
- Coin total is tracked on the server.
- Purchases validate affordability before applying upgrades.

### Boilerplate Scope

- Non-persistent session currency.
- Centralized coin state for each player.
- Upgrade purchase hooks through a simple shop UI.

## 6. Upgrade System

### Description

Players spend coins to improve their performance.

### Upgrade List

- Bigger maximum size
- Size multiplier
- Bigger brush
- Faster brush
- More paint bucket capacity

### Requirements

- Each upgrade has a current level, cost, and max level.
- Costs increase as the level increases.
- Purchases immediately impact gameplay values.
- Upgrade values are derived from shared configuration.

### Boilerplate Scope

- Five upgrade paths.
- Server-authoritative purchase handling.
- Live stat recalculation after purchase.

## World Structure

## Arena Layout

The template should include:

- A shared wall-painting area with multiple paintable wall segments.
- A personal base area for each player.
- Safe spawn points near each base.
- Clear travel distance between base and wall area to create loop tension.

## Player Base

Each base should include:

- Spawn position.
- Refill pad.
- Upgrade/shop interaction zone or UI access.
- Base color or identity matching the player’s paint color when possible.

## UX Requirements

## HUD

The template should display:

- Current paint amount and max capacity.
- Current size.
- Coins.
- Current growth cap.
- Next milestone target and reward.
- Upgrade costs and levels.

## Feedback

The game should provide clear feedback for:

- Successful painting.
- Empty bucket / cannot paint.
- Refill occurring at base.
- Milestone reward earned.
- Upgrade purchased.
- Upgrade purchase denied due to insufficient coins or max level.

## Technical Requirements

## Architecture

The template should be split into:

- Shared config modules in `ReplicatedStorage`.
- Server gameplay authority in `ServerScriptService`.
- Client input and UI in `StarterPlayerScripts`.

## Server Authority

The server should validate:

- Paint actions.
- Refill actions.
- Coin rewards.
- Upgrade purchases.
- Player stat recalculation.

## Tunable Data

The following values should be easy to tweak:

- Base movement and growth values.
- Paint capacity.
- Brush size.
- Brush speed.
- Size multiplier.
- Upgrade costs.
- Upgrade effect strength.
- Milestone thresholds and rewards.
- Arena dimensions.

## Non-Goals For Initial Boilerplate

The first version does not need to include:

- Data persistence.
- Rebirth systems.
- Pets.
- Leaderboards.
- Matchmaking.
- Monetization.
- Advanced VFX or SFX.
- Competitive PvP.
- Mobile-specific polish beyond basic UI support.
- Anti-cheat beyond standard server validation.

## Success Criteria

The template is successful when:

- A player can spawn and understand the loop within seconds.
- Painting walls visibly consumes paint and grows the player.
- Returning to base reliably refills paint.
- Milestones award coins in a satisfying way.
- Coins can be spent on all five upgrades.
- Upgrades noticeably improve gameplay.
- The project is structured cleanly enough for future expansion.

## Future Expansion Opportunities

Potential next features after the boilerplate:

- DataStore persistence.
- Rebirth system.
- NPC quests.
- Daily rewards.
- Cosmetic skins and paint trails.
- Multiple zones or worlds.
- Rare wall types with bonus rewards.
- Team competition or area control.
- Limited-time boosts and gamepasses.
- Companion helpers or auto-painters.

## Recommended Milestone For This Template

The first playable version should deliver:

- Arena generation.
- Paintable walls.
- Brush input.
- Paint bucket depletion and refill.
- Character growth.
- Milestone coin rewards.
- Upgrade purchases for all requested power-ups.
- Basic HUD and shop UI.

## Summary

This Roblox boilerplate is a paint-and-grow progression game template where players paint walls to grow larger, return to base to refill paint, earn milestone coins, and buy upgrades that accelerate future runs. The design is intentionally compact, modular, and extensible so it can serve as the foundation for a much larger simulator-style experience.
