-- Same tree: relative require.
local Counter = require("./Counter")

return {
	counter = Counter,
	read = function(): number
		return Counter.value
	end,
}
