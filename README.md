# LootCollector

Worldforged item, vendor, rare, chest, and loot discovery tracking.

An addon for **Ascension: Conquest of Azeroth** on Conquest Reborn. Maintained by Uncle Bone.

## Download

[Latest stable release](https://github.com/robsdow87/LootCollector/releases/latest) · [Previous versions](https://github.com/robsdow87/LootCollector/releases)

**No release has been published yet.** Current source files must be verified before the first release.

## Installation

1. Download the ZIP attached to a published GitHub Release (not the automatic GitHub source archive).
2. Extract into your World of Warcraft `Interface/AddOns` directory.
3. Ensure the `LootCollector` folder contains its `.toc` file; restart the game.

## Compatibility

Built for the legacy client used by Ascension: Conquest of Azeroth. Questie-X, DBM-CoA, and LootCollector use LootCollector's existing shared channel `BBLC25C`, with distinct message protocols. Preserve compatibility with older clients and addon versions when updating.

## Feedback

[Report bugs and request features](https://github.com/robsdow87/LootCollector/issues). Include addon version, client version, error text, and steps to reproduce.

## Release process

When verified addon source is present in `LootCollector/`, pushing a version tag such as `v1.0.0` triggers the release workflow to validate the folder and package it as a downloadable ZIP. Earlier tagged releases remain accessible.

See [CHANGELOG.md](CHANGELOG.md) for release history.
