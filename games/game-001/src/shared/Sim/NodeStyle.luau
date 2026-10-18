--!strict
--[[
	Sim/NodeStyle — how a resource node is drawn, and how far the drawing reaches.

	WorldView draws a node as one box (`size` = X, height, Z studs). Kingdom/Layout keeps generated nodes
	clear of crop fields, build zones and slots by the larger of the node's footprint (its sim circle) and
	the box's half-diagonal, so a boulder whose corner sticks out past its footprint circle no longer
	touches a farm (user playtest 2026-10-13: "farms contain trees and rocks").

	API
		NodeStyle.STYLE: { [kind]: { size: { number }, color: { number }, material: string } }
		NodeStyle.radius(kind): number    -- half-diagonal of the box on the XZ plane (0 for a kind with no look)
]]

local NodeStyle = {}

NodeStyle.STYLE = {
	tree = { size = { 4, 14, 4 }, color = { 50, 110, 45 }, material = "Grass" },
	rock = { size = { 8, 6, 8 }, color = { 120, 120, 125 }, material = "Slate" },
	goldvein = { size = { 7, 5, 7 }, color = { 230, 190, 60 }, material = "Foil" },
} :: { [string]: { size: { number }, color: { number }, material: string } }

function NodeStyle.radius(kind: string): number
	local style = NodeStyle.STYLE[kind]
	if style == nil then
		return 0
	end
	local hx, hz = style.size[1] / 2, style.size[3] / 2
	return math.sqrt(hx * hx + hz * hz)
end

return NodeStyle
