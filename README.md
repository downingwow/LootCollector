# LootCollector — Conquest of Azeroth

A community-powered discovery addon for **Ascension: Conquest of Azeroth / Conquest Reborn**, extending LootCollector's original Worldforged-item and vendor tracking with rare-creature and chest discoveries.

## Features

- Track and share discovered **Worldforged items**, Mystic Scroll locations, and vendors.
- **Rare creature and treasure chest tracking** with map and minimap markers.
- Searchable rare/chest listings alongside the original LootCollector viewer.
- Record discovered locations and sightings; deduplication helps avoid repeated pins from the same target.
- Rare/chest tooltips with known creature information and available drop data.
- Automatic **loot-table learning** from observed loot, with saved discovery data.
- Rare/chest location and loot-information sharing; right-click contextual sharing and chat-linked information.
- Cooperative global data exchange through LootCollector's existing `BBLC25C` channel, with safe delayed startup so Questie-X and DBM-CoA can coexist.
- Companion folders **LootCollector_CustomImport** (large database imports) and **LootCollector_StarterDB** (optional starter database).
- Spawn/sighting information and import support for community-maintained discoveries.

Some information, including loot tables and spawn timing, is learned from player observations and may be incomplete or approximate.

## Current source package

**Safe Channel Startup** is the latest available package, built on LootCollector 1.0.6 with rare/chest extensions. Source files and a downloadable GitHub Release are **not yet published**.

## Installation

After a release is published, extract all three folders—`LootCollector`, `LootCollector_CustomImport`, and `LootCollector_StarterDB`—into `Interface/AddOns`. The companion folders are included intentionally.

## Downloads and support

[Releases](https://github.com/downingwow/LootCollector/releases) · [Issues](https://github.com/downingwow/LootCollector/issues) · [Changelog](CHANGELOG.md)

**Credits:** Original LootCollector by Skulltrail and community contributors; CoA extensions maintained by Uncle Bone. Community project; not an official Ascension release.
