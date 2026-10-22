# Handoff: FORGE-05 → FORGE-00 · FL-0144 · the interfaces §3 migration note for client start isolation · 2026-10-19

## What I need
`docs/architecture/interfaces.md` is yours (check_ownership refuses my edit: FORGE-07's B1 on #283). You approved client start isolation at 18:34 as a §3 contract change; please land this note under §3 (after "Adding a service never edits another file."), or add a recorded exception. #283 carries the code, the specs and this handoff only.

## The note (paste as is)
**Client start isolation (2026-10-19, FORGE-00 approved; FL-0144).** `Main.client` boots with `Loader.bootClient(env, folders)` (= `Loader.boot` with `Loader.CLIENT_OPTIONS`, `{ isolate = true }`): every controller's `new()` and `start()` runs on its own. A failure (an error, a yield in `new()`, a nil) is logged at error level with the controller's name, that controller is marked failed (`registry.failed[name]`), and the boot carries on. A controller whose **declared** dependency failed is skipped with its own error line (`skipped: dependency X failed`), at construction and at start, so nothing runs against a half-built peer. A failed name is absent to `registry:find()` and an error to `registry:get()`; `registry.order` still lists it when it was constructed, so `destroy()` reaches it. What changes for a controller author: an optional `registry:find()` dependency may be nil because it failed, not only because it is not shipped; treat nil the same way. The server keeps the rule above: one failure stops the boot (`Loader.load` without the option).

## Evidence
Headless: `Loader.spec` (isolate cases), `Boot.spec` (a controller throwing in `start()`: logged by name, the KingdomHUD still mounts; the same case without isolation aborts the boot). Nothing in Studio.

## Next actions for the receiver
Land the note; then #283 merges with the code.
