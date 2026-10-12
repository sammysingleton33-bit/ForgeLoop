# Identity fixture

A tiny Rojo-shaped tree used by `roblox/tests/unit/contracts/ModuleIdentity.spec.luau` to prove that
the harness loader gives every module exactly one identity, whether it is reached relatively or via
`@game/...`, and that it rejects what Roblox rejects. `shared/Bad/*` modules fail on purpose.
Not part of the place build.
