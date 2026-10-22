local http = game:GetService("HttpService")
local ref = http:JSONDecode(game:HttpGet("https://api.github.com/repos/DarkBotGen/atlasbss/git/ref/heads/main"))
local revision = ref and ref.object and ref.object.sha
assert(type(revision) == "string" and #revision == 40 and revision:match("^[%da-f]+$"), "Unable to resolve the latest Atlas+ RBC Edition revision")
local source = game:HttpGet("https://raw.githubusercontent.com/DarkBotGen/atlasbss/" .. revision .. "/atlasbss-showers-smileys.lua")
local run, err = loadstring(source)
assert(run, err)
return run()
