# ArcMayhem

WoW addon — Havoc (curse) indicator for Destruction Warlock.

## What it does

Displays a solid purple square when the player's current target has a curse-type debuff cast by the player (filter `HARMFUL|PLAYER`). Intended to track Havoc uptime but currently triggers on any player-applied curse (Curse of Weakness, etc.) — this is a known limitation.

## Architecture

Single-file Lua addon. No libraries, no XML.

- `ArcMayhem.toc` — addon metadata, interface 120001 (WoW 12.0, The War Within)
- `ArcMayhem.lua` — all logic

### Key design choices

- **Secret value workaround**: WoW 12.0 restricts direct aura value reads. The addon uses `C_CurveUtil.CreateColorCurve()` step curves + `C_UnitAuras.GetAuraDispelTypeColor()` to map dispel types to colors without accessing restricted values. Curve point indices correspond to dispel type enum values (index 2 = Curse).
- **Stacked StatusBar overlays**: Each scanned aura gets a border overlay + fill overlay pair. The fill is inset by `borderWidth` pixels. Only curse-type auras produce visible color; all other dispel types map to transparent.
- **Gating**: Class-gated to Warlock at load time (early return). Spec-gated to Destruction (spec ID 267) at runtime — registers/unregisters aura events on spec change.

### Saved variables

`ArcMayhemDB` — table with: `size` (px, default 80), `borderWidth` (px, default 2), `point`, `relPoint`, `x`, `y` (anchor position, default CENTER/CENTER/0/0).

### Slash commands

`/mayhem` — unlock, lock, size \<10-400\>, reset.

## Development notes

- `SCAN_CAP = 16` — max debuffs scanned per update.
- Overlays are lazily created via `GetOverlayPair(index)` and reused.
- Events: `UNIT_AURA` (target only), `PLAYER_TARGET_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_LOGIN`, `ADDON_LOADED`.
- No build step. Drop the folder into `Interface/AddOns/` and reload.
