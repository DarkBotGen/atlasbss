# Atlas BSS

Lua script and loader. Requires an environment providing `game:HttpGet` and `loadstring`.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DarkBotGen/atlasbss/main/atlasbss.lua"))()
```

The loader fetches the current script from the main branch.

Included changes cover gathering priorities, bloom and petal collection, duped-token filtering, movement command smoothing, Mondo behavior, and optional Bear Morph / Inspire timing. Bear Morph / Inspire timing is off by default.

Compilation and local simulation tests pass. Live-game behavior has not been verified.
