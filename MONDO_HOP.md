# Mondo Hop (normal Atlas+)

Enable Combat > Mondo Chick > Mondo Hop while in the home private server. Paste its invite link into Private Server Invite Link; it is stored locally for the Copy Private Server Link fallback. Keep the normal Atlas+ loader in autoexec.

During the first 14 minutes 30 seconds of each hour, seeing a Mondo in the private server starts a session. Mondo Hop pauses managed farming/travel activities and yields showers, combos, meteor movement, idle guards and crab support. It kills the private Mondo first, loots up to 30 seconds, and chooses a random non-full unvisited public server. After autoexec it scans for Mondo, kills and loots if present, and otherwise hops again. The visited list is capped at 100 entries. At :14:30 it stops the fight/loot loop and attempts return to the saved private instance. Normal farming resumes when the session returns home; it does not restart that hour.

Private return limitation: return uses the original JobId with TeleportToPlaceInstance. Roblox may reject private-instance joins, and this cannot recreate an instance that has shut down. A rejection pauses hopping and displays a failure notice; copy the saved invite and join it manually. The invite is NOT incorrectly passed as a reserved-server access code. Fully automatic return through an invite requires an external launcher or an executor-supported private-server launch method. Autoexec restarts scripts but does not provide that launch method itself.

Local checks cover the cutoff boundary, next-hour window, movement pause/resume, public filtering, session persistence and teleport backoff. Compilation passes. Actual kills, loot pickup, private return permissions and executor autoexec require live testing.
