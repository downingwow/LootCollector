# LootCollector — Find, Track & Share Worldforged Loot, Rares and Treasure

> **[⬇ Download v1.0.9](https://github.com/downingwow/LootCollector/releases/download/v1.0.9/LootCollector-v1.0.9.zip)**


## Current release

# LootCollector-CoA v1.0.9 — Map rollback

- Publishes the latest map rollback package following the v1.0.8 marker-restoration attempt.
- Retains the community discovery viewer, Worldforged tracking, rare/chest records, loot observations, imports and companion databases present in the package.
- Existing BBLC25C sharing and saved data remain intact.

Install LootCollector, LootCollector_CustomImport and LootCollector_StarterDB side by side in Interface/AddOns. Preserve LootCollectorDB_Asc. This rollback does not establish that all UI-specific map-marker issues are resolved; test map pins in your client.

Maintainer: Uncle Bone — https://github.com/downingwow


**LootCollector helps you remember where valuable things have been found in Conquest of Azeroth—and learn from discoveries made by other players.** It began as a community-driven tracker for **Worldforged items and Mystic Scrolls** and has been extended with **rare-creature, treasure-chest, and loot-learning features** for Ascension: Conquest of Azeroth / Conquest Reborn.

## What it does for a player

Imagine someone finds a special Worldforged item, a rare creature, or a chest. Instead of remembering the location yourself, LootCollector can **record it, place it on a map, and exchange compatible discovery information with other players**. Over time, the addon builds a more useful community map.

### 1. Worldforged items and discoveries

- Tracks known locations for **Worldforged items**, including item discoveries collected from your gameplay and shared community information.
- Shows discovered locations as **world-map and minimap pins**.
- Provides a **discovery viewer** for browsing, searching, filtering, and managing records.
- Remembers items you have collected and can distinguish relevant discoveries from already-looted ones.
- Helps clean up duplicate or inaccurate pins, including known bad item/zone combinations.
- Offers item tooltips and location information to help decide what to hunt.

### 2. Navigation to a find

- Can direct you toward a selected Worldforged location using an **arrow/distance display** and optional **TomTom** integration.
- Includes options to skip, clear, or hide a destination rather than forcing the player to follow it.
- Map filters, minimap button, and viewer controls help keep the interface manageable.

A pin is a reported location, **not a guarantee that the item or creature is currently spawned**.

### 3. Rare creatures and treasure chests

The CoA extension adds a separate, persistent **Rare/Chest Tracker**:

- Records supported rare, rare-elite, and world-boss creature sightings, as well as supported treasure-chest discoveries.
- Displays known rare/chest locations on the **world map and minimap**.
- Provides a searchable **Chests/Rares** listing in the LootCollector interface.
- Stores available names, locations, level information, notes, and reported drops.
- Combines duplicate observations to avoid flooding maps with repeated pins.
- Supports manual entries and imports for rare locations, chest locations, estimated respawn times, and drop data.
- Includes right-click/contextual sharing of discovery information where supported.

**Respawn times are estimates**, not guaranteed timers. A creature can move, despawn, or be absent when you arrive.

### 4. Loot-table learning

The rare/chest extension can observe supported loot events and add **seen drops** to the local record. That means a rare's known drops can improve as people kill it and share discoveries. **A learned loot list is not a complete or verified drop table**: an item not yet seen may still drop, and some events may not be captured.

### 5. Community sharing and data quality

- Exchanges compatible records over LootCollector's existing global channel **`BBLC25C`**.
- Allows **Questie-X and DBM-CoA to share the same channel safely** while using their own message protocols.
- Uses deduplication, record validation, and merge rules to reduce spam and repeated sightings.
- Includes sharing-related controls and version compatibility checks.
- Supports an optional **starter database** and a separate **custom-import** addon for adding larger sets of known records.

Sharing requires compatible players online; no central server is continuously collecting data. Other players' records can be incomplete or incorrect.

## Included folders — install all three

The package deliberately contains:
- **`LootCollector/`** — main addon, interface, tracking, maps, and communication.
- **`LootCollector_CustomImport/`** — companion folder for custom data imports.
- **`LootCollector_StarterDB/`** — companion starter data.

Put all three **side by side** under `World of Warcraft/Interface/AddOns/`; do not nest the companion folders inside the main folder.

## Useful rare/chest commands

The included rare/chest module documents these commands:

- `/lcrare list` — list tracked rare/chest records.
- `/lcrare scan` — inspect your current target for a supported rare.
- `/lcrare add rare Name;level;respawnMinutes;drop1,drop2` — add a record manually.
- `/lcrare importline kind|mapID|x|y|name|level|respawnMinutes|drops|notes` — import a record.
- `/lcrare export` — export stored rare/chest information.

Some actions may require a supported target, zone, or correctly formatted record.

## Install / update

1. Back up your **`LootCollectorDB_Asc`** SavedVariables before updating; it contains locally collected discoveries.
2. Extract all three folders from the release ZIP into `Interface/AddOns`.
3. Restart the game and enable LootCollector.
4. Open the LootCollector viewer or use the documented commands. Allow time for cooperative channel startup.

## Current build and limits

**Current source build: v1.0.9.** Map stack-overflow fix and CoA release metadata. Installable ZIPs and version history are published through [GitHub Releases](https://github.com/downingwow/LootCollector/releases).

- Loot-table data grows from observations and is not necessarily complete.
- Rare/chest locations and timers may be approximate.
- An automatic detection event does not imply every custom chest or NPC type is recognized.
- The addon uses the legacy **Interface 30300** client and may not work unchanged on retail WoW.

## Credits and support

Original LootCollector by **Skulltrail**, with contributions from Deidre, Rhenyra, Morty, Markosz, Bandit Tech, xan, Stilnight, Xurkon, Netherborne, Jollyg, and others credited in the addon. CoA rare/chest extensions and distribution maintained by **Uncle Bone**. Community project, not an official Ascension release.

[Report a bug / request a feature](https://github.com/downingwow/LootCollector/issues) · [Changelog](CHANGELOG.md)


## Earlier v1.0.7 changes

Includes the map stack-overflow fix and aligned CoA version metadata. Existing SavedVariables, rare/chest learning and cooperative BBLC25C sharing are retained.

