# Atlas+ Safeshower

The previous shower tween/priority selector has been replaced with the Safeshower code supplied in `message (7).txt`. The integration retains its ownership detection, observed light ordering, movement algorithm, world labels and movement handling.

## Operation

- Enable **Farm Showers** and autofarm. The chaser runs only during gathering in the current field; conversion, travel outside that field, stopping, or death disables it. During gathering, the detector watches for your Star Shower passive popup (`5101364168`) and a matching Star Shower Guide. Overlapping/ambiguous owners are rejected rather than guessed.
- Once your guide is accepted, shower handling takes priority over normal gathering, regardless of gathering order. Active combo catches take priority over showers under the Coconut Team role rules. Main farming, standalone movement, facing, speed overrides, auto-dig and other named movement jobs are suspended. Existing character movement tweens and travel constraints are canceled.
- The supplied chaser starts toward light 1 with a 20% WalkSpeed boost (capped at 210), with departure still planned from the live starting WalkSpeed, aiming to arrive 500ms before the estimated expiry. Subsequent transitions use its live twice-ping lead and 210 PMS cap.
- Light numbers follow observed first appearance. Actual visual removal advances the sequence, with the supplied ping-based early transition when a next light is known. There is no invented fixed 0.3-second spawn schedule.
- Near a light, it brakes and uses the supplied small circular path on the edge facing the next light. It uses `Humanoid:Move`, WalkSpeed and velocity braking, with **no shower tween or density change**.
- On completion or cancellation, the engine restores speed, camera and controls. Paused jobs resume when their settings still permit them. Stop Everything and unloading prevent automatic resumption.
## Controls

Farm Showers controls the integrated chaser. The standalone Safeshower panel, arming controls, graph and report UI have been removed. Numbered world labels and the green TARGET highlight remain. Turning Farm Showers off or using Stop Everything cancels the current run.

## Integration safeguards

Required guide/light visuals are allowed through Hide Particles. Anti-lag leaves the physical WarningDisk and Star Shower Guide properties intact so the supplied detector can recognize their material, size and color.

Only active named movement workers retain restart metadata; it is removed on completion/cancellation. While a shower owns movement, new movement-worker requests are queued instead of starting competing loops. Popup property listeners are disconnected and unregistered when their instances leave the scene. The removed panel no longer retains run or event history. Full cleanup also runs after a partial startup failure.

## Validation and limits

Full-script compilation and isolated tests passed for own-popup/guide recognition, rejecting another player's shower, suspending/resuming movement workers, blocking competing restarts, canceling an existing movement tween, ten observed light removals, restoring speed/input/camera, 500 destroyed popup lifecycles, unloading mid-shower and startup-failure cleanup. Existing priority-config, memory, petal, bloom, smiley, allowlist and bear-timing regressions also passed.

These tests use an engine mock. No live 9–10x catch rate has been measured. The supplied timing estimates and visual observations are not server confirmation of collection; network delays, replication ordering and client stalls can still affect results.

## Saved priorities

The prior config fix remains: `prioritization.order` replaces the empty default during config loading, preserving the saved ordering and enabled flag. Showers now override that ordering while active; the order still applies to other gathering.

Config saves also remember the active preset for the current account. Loading a config launches this Atlas+ release, and startup preserves an existing default config.

Enabled combo coconuts override other gathering targets and cannot be interrupted by lower priority targets. An active shower retains exclusive movement control. Catch success still depends on distance, timing and latency.

Main-owned combos use local role rules: the two spawning alts focus landings in Team Field (Pepper Patch), and the three outside catchers focus landings in Outside Catch Field (default Coconut Field). Each configured catcher in the appropriate group commits; there is no nearest-catcher exclusion. The main joins its own combo after two consecutive observed drops in the same field, and that counter resets on a field change.

For alt-owned combos, the existing coordinator assigns the spawning alt and main alternating turns. The spawning alt accepts only its own combo; outside catchers help with assigned landings in Outside Catch Field. Accounts become available to the coordinator when relevant alt-combo FX are present, even during another activity. Actual assigned catches preempt showers, conversion and other movement, while waiting for a turn does not steal a catch.

Combo movement uses a fast continuous approach (up to at least 180 PMS, with braking near the center). During an actual combo session only, the character root's density is multiplied by ten (clamped to Roblox's property limits) and Massless is disabled. The exact original CustomPhysicalProperties and Massless values restore on completion, target changes, interruption or unload. No density changes apply to shower or normal gathering movement. Cross-field combo travel uses the navigation graph with cancellation/expiry checks and does not invoke the normal travel helper's character-reset failure behavior. Existing coordinator software is unchanged.

Combo tracking now accepts FallingCoconut and KickedComboCoconut follow-ups with an observed landing position and duration. A bounded 30-second chain-owner cache preserves the spawning account across target changes; each new drop receives a distinct local key, and the preceding landing is retired when the next bounce is observed. The UI Tracking line exposes missing landing data. Main, spawning-alt and outside-catcher regressions cover consecutive drops, repeated IDs/positions and target changes. These are mock FX fixtures, not confirmation of the live game's event schema.
