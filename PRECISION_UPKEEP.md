# Precision upkeep

Farming → Maintain Precision / Spam Marks is enabled by default and saved in the normal configuration. It operates during gathering, independently of the older Farm Precise switches.

- Missing Precision or fewer than 10 stacks: prioritize ordinary precise targets to build the buff.
- At 10 stacks with more than 65% duration remaining: prioritize purple precise-mark targets through the existing avoidance/path routine, including during Scorching Star.
- At 65% or less: return to ordinary targets to refresh before expiration, then switch back to marks.

Normal targets rank ahead of closer purple targets during refresh. Physical crosshairs and tracked precise groups use the same policy. Mark routing can use the avoidance graph when a direct line is blocked. Its temporary avoidance map is copied rather than retained in ordinary gathering options. Mark movement yields back to refresh if the buff becomes low during its path.

This takes priority over ordinary gathering order, including petals, while active precision actions are protected from lower priorities. Combo assignments, showers, protected task travel, and loot-only/task modes retain their existing control. The script can only collect targets the game has spawned; it does not force bee abilities to activate.

The source-derived Luau fixture tests build/refresh thresholds, both target formats, mark selection during Scorching Star, gathering priority, range and hazard handling, and task/combo/shower exclusion. Live buff uptime remains dependent on bee abilities, target availability, movement and latency.
