# Low-memory visual settings

Restart Roblox after using older destructive anti-lag settings. Folders already deleted from a live session cannot be recovered by changing the new toggle.

Run the loader, then open **Debug → Anti Lag**:

- Enable **Aggressive Visual Optimization** for low detail, decorative texture stripping, hidden decorations, disabled particles/trails/beams, shadows and post-processing.
- Optionally enable **Hide Bees**, **Hide Flowers**, and **Hide Other Players**. These now hide visuals while preserving instances and collision.
- **Disable 3D Rendering** is available when watching the scene is unnecessary. This mainly reduces rendering work; it is not a promise of lower process RAM.

The optimizer preserves token textures, marks, signs, gameplay folders and hitboxes. Its initial scan is processed in batches, subsequent objects use two managed listeners, and disabling/unloading restores saved properties where the objects still exist. It does not change movement, remotes, streaming properties, asset-download behavior, or detection mechanisms.

## Optional local graphics flags

`ClientAppSettings.low-memory.json` contains only texture-quality and anti-aliasing flags listed in Roblox's published local configuration allowlist. Merge the entries through your launcher's supported local FastFlag configuration; do not overwrite other settings blindly. The file is not installed automatically by the Lua loader. Flag availability and behavior can change with Roblox updates.

- [Roblox's local FastFlag allowlist](https://devforum.roblox.com/t/allowlist-for-local-client-configuration-via-fast-flags/3966569/)
- [Roblox streaming documentation](https://create.roblox.com/docs/workspace/streaming)

Experience streaming settings are not scriptable. Disabling streaming is not a reliable memory optimization, and removing a texture reference does not guarantee Roblox immediately releases its cached image. This profile does not prevent asset downloads, cap RAM, guarantee a particular memory saving, or establish that executor use is permitted by Roblox or the experience.

## Checking sustained memory

Home shows client Lua heap, active tasks and registered connections. Compare those readings with each client's process memory after a consistent warm-up and similar activity. Lua heap is only part of total process memory. A heap/task count that keeps rising under the same workload needs investigation; a stable Lua heap with increasing process memory points to a different allocation category and needs runtime profiling.
