"""FL-0135 mutation rows (FORGE-04's part: the client's Kit asset folder), run by ../mutations.py
(`mutations.py FL-0135`).

One row: (task, file, old, new, spec filter, expected failing test, project). The path prefixes
S, C, X, G, C2 and F come from mutations.py. Add rows for FL-0135 here only (D-038 (7)).
"""
K = C2 + "FeedbackKitController.luau"
M = [
 ("FL-0135", K, '\tkit.setAssetSource(assets)\n', '\tkit.setAssetSource(nil)\n', "FeedbackKit", "passes ReplicatedStorage.Forge.Assets to the Kit", "game"),
 ("FL-0135", K, 'if forge ~= nil then forge:FindFirstChild("Assets") else nil', 'forge:FindFirstChild("Assets")', "FeedbackKit", "passes nil without Forge", "game"),
 ("FL-0135", K, 'deps.kit ~= nil then deps.kit else Kit', 'deps.kit ~= nil then deps.kit else { setAssetSource = function() end }', "FeedbackKit", "with the real Kit, a model in Forge.Assets", "game"),
 ("FL-0135", K, '\tkit.setAssetSource(assets)\n\treturn setmetatable({ _env = env, _registry = registry, assets = assets }, Controller)\n',
  '\treturn setmetatable({ _env = env, _registry = registry, assets = assets, start = function()\n\t\tkit.setAssetSource(assets)\n\tend }, Controller)\n',
  "FeedbackKit", "is set before any controller starts", "game"),
]
