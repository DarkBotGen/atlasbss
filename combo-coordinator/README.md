# Atlas+ Coconut Team — Windows launcher

Run the coordinator on **one** Windows 10/11 x64 computer. It can be a separate, dedicated computer without Roblox. All Roblox accounts connect to it over the internet; they must also be in the same Roblox server.

## Start

1. Extract the ZIP. Open the `combo-coordinator` folder and double-click **Start Atlas Combo.cmd**.
2. The downloadable preview includes portable Python from python.org and the official Cloudflare tunnel helper, verified against SHA-256 checksums. If either runtime is missing, the launcher downloads it automatically. No Python installation, administrator access, router changes, or Roblox credentials are needed.
3. A local browser page opens. Wait until it says **Ready**, then click **Copy connection code**. Leave the launcher window open and keep this computer awake and connected.
4. Relaunch Atlas+ with your existing GitHub loader on each Roblox computer, or use the included `atlasbss.lua`. Open **Farming → Coconut Team** to configure the new client.

## In Atlas+

Open **Farming → Coconut Team** on the main account:

- Paste the connection code into **Paste Connection / Team Code**.
- Select **Main Account**, **Spawning Alt 1**, **Spawning Alt 2**, and the three optional **Outside Catcher** accounts.
- Set **Team Field** to the field containing the main and two spawning alts.
- Click **Copy Team Code** and paste that code into the same box on every other account. This copies the connection and roster together. The account choices and connection are saved in each account's config.
- Enable **Coordinate Coconut Team** on all participating accounts.
- Enable **Fast Combo Catching** on the three outside catchers. Their autofarm may remain off.
- Main and spawning alts need autofarm gathering enabled. Shower collection, conversion, combat, death and Stop Everything make an account unavailable for team catches.

The menu's status shows connection/assignment state and the last observed combo owner. **Unknown owner** means the game did not expose a usable player identity; team mode does not invent ownership or alternating turns for that coconut.

## Catch rules

- The main has priority for its own combo when it can reach the landing. A spawning alt or outside catcher covers unavailable/unreachable catches. A returning main takes priority on the next landing, without stealing an already assigned catch halfway through.
- For an alt's combo, the spawning alt is preferred first, followed by the main, then the spawning alt again. Growth turns are inferred from fresh position samples at landing time; assignment alone never counts as a catch.
- Outside catchers have no alternating role. When a combo leaves the team field and the core accounts cannot reach it, a reachable outside catcher is assigned. A reachable spawning alt still gets a needed growth turn.
- Each landing has one assigned catcher, and each account has at most one assignment. Disconnects/busy accounts release their assignments after the prior short movement lease expires.
- An active shower has priority over combo movement. Movement uses continuous Humanoid movement and dynamic WalkSpeed, based on the coconut's observed duration. It does not use a shower's fixed lifetime, tweening, or teleportation.
- With **Coordinate Coconut Team off** and **Fast Combo Catching on**, the standalone mode needs no launcher. It catches outside the selected team field without alternating. Multiple independent catchers can compete; use coordination on all six accounts for shared assignments.

## Continuous operation and recovery

This initial easy-launch version uses a Cloudflare Quick Tunnel. Its address lasts while the tunnel process is running. Restarting the launcher creates a new address and connection code: paste the new code on all accounts (or copy a new team code from the main).

Quick Tunnels have **no uptime guarantee** and are documented by Cloudflare as a testing/development service. Leaving the computer on does not make this a guaranteed uninterrupted 24/7 service. For a permanent address and production hosting, use a named tunnel or a hosted endpoint in a later deployment. [Cloudflare Quick Tunnel limitations](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

When the coordinator is unreachable or replies arrive too late, coordinated movement stops rather than letting every account chase the same coconut. It reconnects with a bounded delay. Leave **Fast Combo Catching** as a standalone option only if you intentionally disable coordination.

The connection code is a team access credential. Keep it within your team. The service exchanges usernames, Roblox server ID, player positions/availability, and coconut observations. It does not read Roblox cookies or passwords. Its setup page is accessible locally only; external requests require the connection key.

## Verification limits

Automated tests cover assignment priority, alt turns, outside catchers, main interruptions, expiring leases, stale replies, server isolation, HTTP authentication, bounded long-run state and movement restoration. Portable Windows Python, the official tunnel binary, and Windows child-process cleanup were also checked.

**Six-account live gameplay has not been verified.** FX ownership identifiers and visual deadlines need a live check. Position at the landing is evidence of a possible catch, not a server acknowledgement. Latency, obstacles and missed/changed game effects can still cause misses; this is an experimental integration, not a guaranteed combo-uptime result.

Developer tests: `python -m unittest discover -s combo-coordinator -p test_coordinator.py` and the Luau test in `tests/combo_controller_test.luau`.
