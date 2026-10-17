# Atlas+ Safeshower

The previous shower tween/priority selector has been replaced with the Safeshower code supplied in `message (7).txt`. The integration retains its ownership detection, observed light ordering, movement algorithm, diagnostics, input handling and report UI.

## Operation

- Enable **Farm Showers**. During autofarm, the detector watches for your Star Shower passive popup (`5101364168`) and a matching Star Shower Guide. Overlapping/ambiguous owners are rejected rather than guessed.
- Once your guide is accepted, shower handling takes **absolute priority**, regardless of gathering order. Main farming, standalone movement, facing, speed overrides, auto-dig and other named movement jobs are suspended. Existing character movement tweens and travel constraints are canceled.
- The supplied chaser starts toward light 1 at the live starting WalkSpeed, aiming to arrive 500ms before the estimated expiry. Subsequent transitions use its live twice-ping lead and 180 PMS cap.
- Light numbers follow observed first appearance. Actual visual removal advances the sequence, with the supplied ping-based early transition when a next light is known. There is no invented fixed 0.3-second spawn schedule.
- Near a light, it brakes and uses the supplied small circular path on the edge facing the next light. It uses `Humanoid:Move`, WalkSpeed and velocity braking, with **no shower tween or density change**.
- On completion or cancellation, the engine restores speed, camera and controls. Paused jobs resume when their settings still permit them. Stop Everything and unloading prevent automatic resumption.
- **Run without autofarm** remains supported. With that enabled and autofarm off, the same detector/chaser runs. Outside an owned shower, the supplied standalone passive-token collector is disabled so it does not compete with Atlas farming.

## Controls

The supplied **Atlas+ Safeshower** panel includes Armed, run diagnostics, numbered lights and Copy run report. Right Shift cancels/disarms. Closing its panel stops the chaser; reload Atlas to recreate it. Turning Farm Showers off cancels the current run. The normal main Stop Everything control remains authoritative.

## Integration safeguards

Required guide/light visuals are allowed through Hide Particles. Anti-lag leaves the physical WarningDisk and Star Shower Guide properties intact so the supplied detector can recognize their material, size and color.

Only active named movement workers retain restart metadata; it is removed on completion/cancellation. While a shower owns movement, new movement-worker requests are queued instead of starting competing loops. Popup property listeners are disconnected and unregistered when their instances leave the scene. Run history is limited to ten runs, and the supplied event history remains limited to 400 entries. Full cleanup also runs after a partial startup failure.

## Validation and limits

Full-script compilation and isolated tests passed for own-popup/guide recognition, rejecting another player's shower, suspending/resuming movement workers, blocking competing restarts, canceling an existing movement tween, ten observed light removals, restoring speed/input/camera, 500 destroyed popup lifecycles, unloading mid-shower and startup-failure cleanup. Existing priority-config, memory, petal, bloom, smiley, allowlist and bear-timing regressions also passed.

These tests use an engine mock. No live 9–10x catch rate has been measured. The supplied timing estimates and visual observations are not server confirmation of collection; network delays, replication ordering and client stalls can still affect results.

## Saved priorities

The prior config fix remains: `prioritization.order` replaces the empty default during config loading, preserving the saved ordering and enabled flag. Showers now override that ordering while active; the order still applies to other gathering.
