# Atlas BSS

Lua script and loader. Requires an environment providing `game:HttpGet` and `loadstring`.

```lua
local http = game:GetService("HttpService")
local ref = http:JSONDecode(game:HttpGet("https://api.github.com/repos/DarkBotGen/atlasbss/git/ref/heads/main"))
local revision = ref and ref.object and ref.object.sha
assert(type(revision) == "string" and #revision == 40 and revision:match("^[%da-f]+$"), "Unable to resolve the latest Atlas revision")
local source = game:HttpGet("https://raw.githubusercontent.com/DarkBotGen/atlasbss/" .. revision .. "/atlasbss.lua")
local run, err = loadstring(source)
assert(run, err)
return run()
```

The loader resolves the current main revision through GitHub, then fetches its immutable script URL. This avoids receiving an older cached raw main build. Stump Even Coverage and its strip logic are removed; the Stump route uses the perimeter plus one middle crossing.

Included changes cover gathering priorities, bloom and petal collection, duped-token filtering, movement command smoothing, Mondo behavior, and optional Bear Morph / Inspire timing. Bear Morph / Inspire timing is off by default.

Precision upkeep and mark prioritization are enabled by default; see [Precision upkeep](PRECISION_UPKEEP.md).

Four field quadrants and a testing overlay are available in Farming; see [Field positions](FIELD_POSITION.md).

Compilation and local simulation tests pass. Live-game behavior has not been verified.
