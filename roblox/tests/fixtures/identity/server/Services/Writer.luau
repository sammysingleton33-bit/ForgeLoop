-- Cross-tree: server code reaches shared code only through @game.
local Counter = require("@game/ReplicatedStorage/Forge/Counter")

return {
	counter = Counter,
	bump = Counter.bump,
}
