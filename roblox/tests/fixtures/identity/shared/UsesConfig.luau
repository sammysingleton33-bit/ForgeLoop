-- Config is its own tree (games/<game>/config in the real project): reached with @game.
local Settings = require("@game/ReplicatedStorage/Forge/Config/Settings")

return { settingsName = Settings.name }
