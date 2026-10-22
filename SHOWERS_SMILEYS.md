# Original Atlas: fast Showers + Smileys

Separate script: `atlasbss-showers-smileys.lua`.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DarkBotGen/atlasbss/main/loader-showers-smileys.lua"))()
```

This build starts from the untouched original Atlas source, not Atlas+. It adds the fast first-to-last star shower collector with numbered world indicators, and a Farm Smileys toggle with ready-token selection and bounded retries. Other farming and RBC behavior stays original. It does not include Atlas+ coconut-team coordination, quadrant routes, or RBC rewrites.

Enable Auto Farm and Farm Showers to collect showers while gathering. Enable Farm Smileys for the smiley collector. The separate loader resolves the current Git revision and downloads only this separate build. The existing main script and loader are unchanged.

Settings and cache files use separate `atlas-showers` names. Loading either build replaces the running Atlas instance; do not run both together.

Cleanup changes retire completed tasks, disconnect replaced listeners, expire synthetic targets and visited marks, remove orphaned precision groups, bound log queues, and shut down shower inputs and movement on unload. Local tests cover 100,000 token and 100,000 duped-token lifecycles, target expiry, late smiley icons, collector retries, 500 shower popup lifecycles, and mid-shower unload. These checks cannot guarantee zero memory growth or catches in a live Roblox session; the game and execution environment also retain memory.

Original source SHA-256: `fad2bfc17b1e55993c7473b1428632ebd85fbc9564eca3e78cfd6d49be372e2b`.

Validation: Luau compilation and `tests/showers_smileys_{engine,tracking,collection,retention}_test.luau`. Test fixtures contain the relevant extracted production functions with mocked Roblox APIs.
