# Star shower targeting

The controller records each observed falling star with a high-resolution local timestamp and landing deadline. It selects the earliest reachable landing, keeps that target committed, and advances after impact or disappearance. It skips expired, unreachable, out-of-field, or unsafe targets. Stable ordering replaces nearest-target selection, whole-second timestamps, and transparency-based ordering.

Both normal gathering and the standalone fast-shower mode use the same controller. Custom gathering priorities remain effective, including preemption by categories ranked above Showers.

## Settings

- **Farm Showers:** enables shower collection.
- **Dynamic Shower Speed:** enabled by default. With the existing **Fast Shower Tween** enabled, chooses speed using distance and remaining landing time. Late or distant targets request higher speed.
- **Shower Speed Cap:** limits dynamic fast movement, 40–400 studs/second; default 400, matching the previous gathering tween speed ceiling.

Normal walking uses the Humanoid's current WalkSpeed. The new controller does not change WalkSpeed. With dynamic speed disabled, Fast Shower Tween retains its previous fixed 400-stud/second gathering speed.

Targets are reached before their expected impact and held through impact, with a short timing allowance rather than the previous five-second timeout. Marker timings remain estimates: physical warning disks use 1.9 seconds, consistent with the prior script. Network delays, missed spawn events, obstacles, higher-priority gathering, and movement limits can still prevent a 9–10x shower. Collection is not falsely acknowledged as confirmed by the server.

The implementation adds no per-star event listener or delayed task. Metadata is pruned by the existing maintenance sweep. Tweens are canceled/destroyed on completion, preemption, stop, controller reset, script unload, and cancellation of the farming/standalone task.

Compilation and isolated Luau tests passed for earliest-falling selection, stable target commitment, unreachable skips, field/range/hazard checks, dynamic speed and cap, a ten-star sequence, walking speed preservation, interruption cleanup, and 10,000 expired records. Live 9–10x collection has not been measured.
