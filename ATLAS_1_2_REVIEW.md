# Atlas 1.2 review and RBC Edition merge

The supplied atlas1.2.lua was inspected as source data; it was not executed. It uses renamed state variables, a different config schema and a different task scheduler, and contains a version-expiry kick. Its functions cannot be substituted directly into Atlas+.

Useful controls adapted from the supplied source:
- RBC-specific booster and sticker-stacker controls with minimum-round settings. Normal Atlas+ now has these controls. Visits happen between rounds, before starting the timer; selected boosters can also be checked before entering a new challenge when the minimum is 1. Sticker selection/ticket mode uses the existing fixed stacker logic.

Movement review:
- Atlas 1.2 tracks FlyingEntity moves and uses Pos/PosNext corridors and saw Start/EndPos paths. Atlas+ already predicts these hazards, tracks projectiles, bounds hazard maps and checks live mob models.
- Atlas 1.2 caches an avoidance graph. Its cache compares a retained map reference, which can miss changes when that same map is mutated. That cache was not imported.
- Its field fallback behavior already has an equivalent in Atlas+ ResolveField. Existing quadrant boundaries, guards and field-arrival fixes remain in place.
- The merged Precision collector rechecks live hazards while approaching a target.

RBC Edition features merged into normal Atlas+:
- Hourly drive, ticket and selected material reports, including Loaded Dice session usage and ticket-budget estimates.
- Independent RBC boosters and Loaded Dice with persistent 15-minute cadence on unfinished pollen-quest fields.
- Boosted field color defaults with named-field quest protection.
- Red bee defaults: Digital, Vicious, Precise, Bear, Windy, then the remaining established order. Saved custom priorities still override defaults.
- Earlier Precision refresh and sustained target-contact confirmation; improved smiley contact during RBC.
- Fixed stinger eligibility, round filters and configured intervals.
- Round-14+ conversion offer filtering, one reroll, then quit if no safe offer; active conversion quest protection.
- Preset reload stays in normal Atlas+, settings flush before teleport, and empty-default bee-priority maps now load correctly.

Normal Atlas+ retains its existing RBC safety, dynamic team following, bee-priority editor, Mondo Hop, crab support, meteor catching, custom priorities and quadrant features. RBC Edition remains a separate file and loader.

Validation: full Luau compilation and tests extracted from the merged production functions for rates, boost choices, late conversion, Precision selection/contact, stingers and config persistence. These are local mocks, not live Roblox tests; no promise of zero leaks or perfect avoidance is made.
