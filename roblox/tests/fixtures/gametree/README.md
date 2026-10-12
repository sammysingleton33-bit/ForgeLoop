# Fixture: framework (Forge) + game (Game) trees (D-022)

Used by `roblox/tests/unit/contracts/GameTree.spec.luau`. Mirrors `games/game-001/default.project.json`:
framework `forge/` mounted as the Forge trees, game `game/` as the Game trees, `config/` as
`ReplicatedStorage.Forge.Config`. `Bad/` modules each break one require rule.
