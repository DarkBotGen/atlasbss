# Atlas+ RBC Edition

Separate script: `atlasbss-showers-smileys.lua`.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DarkBotGen/atlasbss/main/loader-rbc-edition.lua"))()
```

This build starts from the untouched original Atlas source, not Atlas+. It adds the fast first-to-last star shower collector with numbered world indicators, and improved smiley collection through the existing Farm Duped Tokens toggle and Smiley Token Wait Duration timer, with ready-token selection and bounded retries. Other farming and RBC behavior stays original. It does not include Atlas+ coconut-team coordination, quadrant routes, or RBC rewrites.

Enable Auto Farm and Farm Showers to collect showers while gathering. Enable Farm Duped Tokens for smiley collection; the existing Smiley Token Wait Duration controls when smileys become eligible. The separate loader resolves the current Git revision and downloads only this separate build. The existing main script and loader are unchanged.

Settings and cache files use the normal Atlas paths, including `atlas/`, `atlas-<player>.json`, and `atlascache-<player>.json`. Normal Atlas+ presets load automatically. Unknown options are ignored by this build and preserved when saving an existing preset. Existing default configs are not overwritten. Loading either build replaces the running Atlas instance; do not run both together.

Cleanup changes retire completed tasks, disconnect replaced listeners, expire synthetic targets and visited marks, remove orphaned precision groups, bound log queues, and shut down shower inputs and movement on unload. Local tests cover 100,000 token and 100,000 duped-token lifecycles, target expiry, late smiley icons, collector retries, 500 shower popup lifecycles, and mid-shower unload. These checks cannot guarantee zero memory growth or catches in a live Roblox session; the game and execution environment also retain memory.

Original source SHA-256: `fad2bfc17b1e55993c7473b1428632ebd85fbc9564eca3e78cfd6d49be372e2b`.

Validation: Luau compilation and `tests/showers_smileys_{engine,tracking,collection,retention,config}_test.luau`. Test fixtures contain the relevant extracted production functions with mocked Roblox APIs.

The in-game title is Atlas+ RBC Edition. The shower collector comes from Atlas+; its activity gate is connected to original Atlas status updates even when dashboard and graph reporting are disabled. The old separate loader remains compatible.

RBC Edition also includes Atlas+ reversible visual optimization: hide bees/frogs/flowers/balloons/other players, strip decorative textures, disable visual effects, and aggressive visuals. These preserve game containers, collision and functional token identifiers. Optimizer listeners and saved-property records are released on removal, disable and unload. Disable 3D Rendering owns one overlay and rendering is restored on unload. Graph status/field histories are bounded when their sender stalls.

RBC field dropdowns, upgrade selections, Buy Cog Upgrades and Auto Buy Upgrades load from normal configs. Unset dropdown/modal defaults accept their saved values; deselections replace old selection tables rather than merging removed entries back in. Unsupported settings are preserved on save.
