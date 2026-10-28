# LootCollector

The GitHub project README (features, FAQ, screenshot placeholders, install) lives at the repository root:

**[../README.md](../README.md)**

This folder is the addon package you copy into `Interface\AddOns`.

## Rare and Chest Tracker (added build)

This build adds a persistent rare-creature/chest database stored in `LootCollectorDB_Asc.global.rareChest.records`, separate from item-only Worldforged discoveries. The tracker shares short discovery records through LootCollector's configured default public channel (`Comm.channelName`) and merges incoming records by kind, map, coordinates, and name without rebroadcasting them.

Slash commands:

- `/lcrare add rare Name;level;respawnMinutes;drop1,drop2` (also `chest`, `highrisk`, `warmode`, or `object`)
- `/lcrare list`
- `/lcrare importline kind|mapID|x|y|name|level|respawnMinutes|drops|notes`
- `/lcrare export`
- `/lcrare scan` (checks current target)

Automatic capture records targeted creatures classified by the game as rare/rare elite/world boss, and targeted chest/cache/coffer objects when a loot window opens. World-map pins display stored records for the currently viewed map and show available metadata in a tooltip. Known locations and drop tables can be added manually with `importline`; the addon does not ship a verified Conquest of Azeroth rare/chest atlas, and timers remain estimates unless confirmed by gameplay observations.

Sharing uses bounded plain-text records and validates the type and coordinates before merging. Older LootCollector versions will ignore these new records unless updated with this module.
