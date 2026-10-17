# Atlas+ star shower targeting

The controller records each observed falling star with a high-resolution local timestamp and landing deadline. It selects the earliest reachable landing, keeps that target committed, and advances after impact or disappearance. It skips expired, unreachable, out-of-field, or unsafe targets. Stable ordering replaces nearest-target selection, whole-second timestamps, and transparency-based ordering.

Both normal gathering and **Run without autofarm** use the same walking controller. Custom gathering priorities remain effective during autofarm, including preemption by categories ranked above Showers. Standalone shower collection does not act on stale autofarm priorities and yields when autofarm is enabled.

## Settings

- **Farm Showers:** enables shower collection.
- **Dynamic Shower Speed:** enabled by default. Temporarily increases Humanoid walking speed using distance and remaining landing time. Late or distant targets request higher speed. Uses continuous `MoveTo` movement.
- **Shower Speed Cap:** limits the added walking speed, 40–200 studs/second; default 120. A natural walking speed already above the selected cap is preserved.
- **Run without autofarm:** retained in Debug. With Farm Showers enabled and autofarm off, collects showers in the player's current field. No Fast Shower Tween setting is required.

With dynamic speed disabled, shower collection uses the current walking speed. With it enabled, the temporary boost is released on arrival, interruption, stop, task cancellation, character change, and unload. Restoration preserves externally observed speed changes rather than restoring an obsolete boosted value. The general walk-speed task yields while the shower controller owns the temporary speed adjustment.

Shower movement creates no Tween, AlignPosition, or CFrame movement. The Fast Shower Tween control has been removed. Other optional movement features remain separate.

## Shower-only density

While actively collecting a shower star, the controller multiplies each current character BasePart's effective density by **10**, capped at Roblox's maximum of **100**. It preserves friction, elasticity, their weights, acoustic absorption, and Massless settings. This includes standalone shower collection. Merely detecting or selecting a star does not change density.

Original CustomPhysicalProperties values are restored when collection completes or is interrupted, stopped, canceled, reset, or unloaded. This includes restoring `nil` for parts that originally used material defaults. A newer external physical-property update is left intact. Properties are captured once per active star and are not compounded or scanned every frame. Parts added after that snapshot are not changed until the next star.

The density adjustment runs only inside the shower collector. Other gathering, travel and combat paths do not activate it. Greater density changes mass; it does not guarantee that drift or missed stars are eliminated.

Compilation and isolated tests passed for 100 collection cycles, exact restoration, no stacking, density caps, preserved properties, and interruption/error cleanup. Reference: [Roblox PhysicalProperties](https://create.roblox.com/docs/reference/engine/datatypes/PhysicalProperties).

Targets are reached before their expected impact and held through impact, with a short timing allowance rather than the previous five-second timeout. Marker timings remain estimates: physical warning disks use 1.9 seconds, consistent with the prior script. Network delays, missed spawn events, obstacles, higher-priority gathering, and movement limits can still prevent a 9–10x shower. Collection is not falsely acknowledged as confirmed by the server.

The implementation adds no per-star event listener or delayed task. Metadata is pruned by the existing maintenance sweep. Walking commands and speed adjustments are released on completion, preemption, stop, controller reset, script unload, and cancellation of the farming/standalone task.

Compilation and isolated Luau tests passed for earliest-falling selection, stable target commitment, unreachable skips, field/range/hazard checks, dynamic walking speed and cap, a ten-star sequence, speed restoration, external buff updates, standalone collection/handoff, interruption cleanup, and 10,000 expired records. The test rejects attempts to create a shower tween. Live 9–10x collection has not been measured. Changing WalkSpeed does not guarantee server acceptance or a particular collection multiplier.
