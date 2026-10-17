# Memory retention audit — October 17, 2026

This release fixes verified script retention paths and reduces task allocation. It has passed isolated Luau tests; it has **not** had a five-client live Roblox soak test. No measured RAM reduction or guarantee of leak-free operation is claimed.

## Findings and changes

| Path | Evidence in the previous version | Change |
| --- | --- | --- |
| Failed precise paths | Both `dodgePrecise` and `dodgeMarks` inserted objects into a strong `touchedMarks` table and returned without scheduling removal. Repeated failures could retain distinct targets indefinitely. | All touched entries now have timestamps, including failure paths. One managed sweep removes them after their 1–3 second cooldown. |
| Planters | Removal depended on finding a GUI child and reading its text. If children were already dismantled, removal skipped the record, which held references to planter descendants. Removal by name could also select the wrong instance. | Track the originating instance; remove every matching record by identity. Periodic pruning handles missed removal events. |
| Synthetic tokens/effects | Each event allocated a delayed task. Early collection removed the tracking entry but left its task holding the entry or event payload until expiry. This was avoidable transient retention and allocation churn, rather than proof of an unlimited leak with valid finite durations. | Twelve expiry sites now store deadlines on live entries. The existing maintenance sweep removes expired entries without per-event tasks. ID reuse refreshes the current entry safely. Orphan precise-group metadata is removed after early collection. |
| Alert handlers | Corruption and gummy-beacon callbacks slept for 240/62 seconds. Disconnecting the event did not cancel callbacks already sleeping; older callbacks could also clear refreshed state. | Two scalar deadlines replace the sleeping callbacks. New alerts update the deadline. |
| Log transports | Dashboard logs spawned another send task every 40 seconds; console logs spawned one per 20 lines. A stalled transport could accumulate tasks and captured batches. | At most one task per transport. Pending queues keep the latest 200 dashboard and 20 console lines. Under prolonged stalls, older queued lines are discarded. Existing 30-label UI limit remains. |
| Graph history | Status/field reporting continued adding timestamp keys if the graph task stalled or stopped before its hourly reset. | Each history is limited to 3,601 second buckets. Out-of-window updates replace the final bucket until reset. |
| Visual optimizer | Weak Instance keys were being used as restoration bookkeeping. Weak references are not a reliable object-lifecycle signal. Initial scans also held already-processed object references until completion. | Explicit saved-property ownership, removal listeners that restore/release records, and progressive scan-reference release. A scan skips objects removed before processing. Four total listeners while enabled, all removed on disable/unload. |

The earlier fixes for dark-flame expiry, task/connection registries, bounded station discovery, and the dashboard queue remain in place. This pass reviewed the remaining connections, task creation, hooks, tracked maps, logging, visual restoration, and shutdown paths. It does not prove the executor or game modules are free of leaks.

## Validation

The standalone fixtures in `tests/` were generated from the modified production sections and run with the Luau CLI:

- 100,000 ordinary-token and 100,000 duped-token spawn/collect/expiry cycles.
- 100,000 touched-mark records, including the failure-path lifetime.
- Reused bubble/duped IDs, every converted synthetic-effect expiry branch, and early precise collection metadata cleanup.
- Planter removal after descendants disappear, plus fallback pruning.
- Refreshed corruption state surviving its previous expiry.
- 10,000 log messages while both transports remain stalled: two send tasks, 220 pending lines, 30 visible labels; queues flush when transport slots become available.
- Ten simulated hours of graph updates with no hourly consumer reset.
- 10,000 transient visual records restored and released without increasing the baseline record count.
- 10,000 dark-flame lifecycles and stale-instance pruning.

Full script compilation passed. Existing local lifecycle, smiley, allowlist, bear timing, petal, bloom, Mondo, movement, and gathering-priority regression suites also passed. Mocks validate script behavior; they do not reproduce Roblox engine allocations, event ordering, or executor behavior completely.

## Applying and checking the release

Restart Roblox and run the existing loader to obtain the new script in each client. The update does not modify code already executing in an existing client.

After warmup, compare the Home panel's client Lua heap/task/connection counts with each Roblox process's memory over a sustained farming session. Compare similar fields and activity. The displayed heap includes other client Lua code and is not Atlas-only. This release should remove event-scaled timer growth; temporary spikes and asset-cache growth can still occur. Total process memory alone cannot attribute a leak to this script.

If memory continues climbing, simultaneous heap, task/connection, and process-memory trends are needed to separate remaining script retention from game, renderer, and executor allocations. Aggressive visual optimization is not a hard memory limit.

Reference: Roblox's [memory diagnostics](https://create.roblox.com/docs/performance-optimization/improve) and [weak-table semantics](https://create.roblox.com/docs/luau/metatables).
