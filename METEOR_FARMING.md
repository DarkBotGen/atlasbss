# Meteor farming

Enable Farm Meteor Showers. Dynamic Meteor Speed is enabled by default and saves in config.

Targets are ordered by FX landing deadlines (FallDuration), not meteor size. Physical purple warning disks inherit a matching FX deadline when available; without timing metadata they use observation order. The route re-evaluates each heartbeat and holds at the active landing point until it expires/disappears. Loot gathering resumes when no current-field meteors remain.

Walking speed scales with distance and time remaining, allowing up to 210 while preserving a higher pre-existing speed. It restores when chasing ends, travel begins, the toggle turns off or the script unloads. A heartbeat watchdog restores abandoned speed changes after 0.25 seconds. This uses normal MoveTo movement, without adding meteor tweens; normal travel between fields is retained.

Source-derived tests cover deadline ordering, size independence, physical/FX matching, observation fallback, cleanup, speed cap/restoration, and the dynamic-speed toggle. Full meteor catches require live Roblox verification; simultaneous or unreachable impacts cannot all be guaranteed.
