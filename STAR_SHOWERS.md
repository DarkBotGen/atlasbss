# Atlas+ shower collection

Enable **Farm Showers** to collect showers using tweens. **Run without autofarm** remains available for standalone collection in the player's current field. Fast Shower Tween is no longer a separate required toggle.

The controller selects the **earliest reachable expected impact**, rather than the nearest star. It tweens to the center, stays through the expected landing, and proceeds through the remaining stars in impact order. It rechecks the order every 50ms so a newly observed earlier impact can take precedence. Stable observation order breaks equal-deadline ties.

Movement uses linear tweens at 400 studs/second. The shower controller does not change WalkSpeed, density, Massless, friction, elasticity, or any other physical properties. The previous dynamic walking and density controls have been removed. Disabling Farm Showers, stopping, preemption, cancellation, errors and unloading cancel and destroy its active tween.

Custom gathering priorities remain effective during autofarm. Standalone mode ignores stale autofarm priorities and yields when autofarm is enabled. Field, range and hazard checks still apply. Impossible and expired targets are skipped so they cannot block later stars.

Landing times are estimates from observed spawn timing, using the existing 1.9-second shower interval. The script does not receive server confirmation of each catch. Network delays, inaccurate observed timings and higher-priority interruptions can still cause misses; a particular 9–10x multiplier is not guaranteed.

Compilation and isolated tests passed for a ten-star sequence, earliest-impact versus nearest selection, earlier-impact rerouting, impossible targets, centered arrival, all cancellation paths, standalone collection/handoff, and 10,000 expired records. No live multiplier measurement has been performed.

# Saved gathering priorities

The priority order and Use Custom Order flag are stored inside the selected config under `prioritization`. Reordering already saved the config, but the previous loader merged arrays by iterating the default array's keys, dropping the saved order when the default was empty. The loader now replaces the priority array with a copy from the config. The existing normalizer removes unknown/duplicate entries and appends newly added categories.

Compilation and tests passed for saving a reordered list, ten fresh reloads, enabled/disabled flags, older configs, partial lists and switching presets. Existing saved orders can now load; orders already overwritten by a previous reset must be set again.
