--!strict
--[[
	UI/JobModel — the job panel (FL-0065, Kingdom panel "Jobs" tab) as data, pure. Counts come only
	from the server's population (Kingdom.Population / Kingdom.GetPopulation: my kingdom's
	CitizenService:getPopulation { total, byJob, cap }); a change is a request
	(Kingdom.SetJobQuota(job, count) → (boolean, errorCode?)) that the server applies to its quota and
	fills from the hauler pool about once a second. So the panel shows what the server says, plus
	"Asking… 3 → 4" while a request is on its way and "Moving… 3 → 4" until the count arrives.

	JobModel.JOBS                           quota jobs in panel order (FORGE-01 config Jobs.jobOrder
	                                        without the hauler pool): { id, name, sub, icon }
	JobModel.view(population?, state?, now) -> View
		state = { pending = { [job]: target }, requested = { [job]: { target, at } } }
		View = { known: boolean,
		         summary = { total, cap?, free },
		         rows = { { id, name, sub, icon, count, note?, busy, canAdd, canRemove } },
		         pool = { count, text },            the hauler pool, shown as "Free citizens"
		         soldiers = { count } }
	JobModel.REQUEST_HINT_SEC                how long "Moving…" waits for the count to arrive
]]

local JobModel = {}

JobModel.REQUEST_HINT_SEC = 5
JobModel.MAX_QUOTA = 50 -- G8: Kingdom.SetJobQuota count is integer(0, 50)

JobModel.JOBS = table.freeze({
	table.freeze({ id = "farmer", name = "Farmers", sub = "Grow food", icon = "food" }),
	table.freeze({ id = "woodcutter", name = "Woodcutters", sub = "Cut wood", icon = "wood" }),
	table.freeze({ id = "miner", name = "Miners", sub = "Stone and gold", icon = "stone" }),
	table.freeze({ id = "builder", name = "Builders", sub = "Raise buildings", icon = "build" }),
})

local function isJob(id: string): boolean
	for _, job in JobModel.JOBS do
		if job.id == id then
			return true
		end
	end
	return false
end
JobModel.isJob = isJob

function JobModel.view(population: any, state: any, now: number): any
	local byJob = if population then population.byJob else {}
	local pending = if state and state.pending then state.pending else {}
	local requested = if state and state.requested then state.requested else {}
	local free = byJob.hauler or 0
	local rows = {}
	for _, job in JobModel.JOBS do
		local count = byJob[job.id] or 0
		local target = pending[job.id]
		local note = nil
		if target ~= nil then
			note = `Asking… {count} → {target}`
		else
			local asked = requested[job.id]
			if asked and asked.target ~= count and now - asked.at < JobModel.REQUEST_HINT_SEC then
				note = `Moving… {count} → {asked.target}`
			end
		end
		local busy = target ~= nil
		table.insert(rows, {
			id = job.id,
			name = job.name,
			sub = job.sub,
			icon = job.icon,
			count = count,
			note = note,
			busy = busy,
			canAdd = population ~= nil and not busy and free > 0 and count < JobModel.MAX_QUOTA,
			canRemove = population ~= nil and not busy and count > 0,
		})
	end
	return {
		known = population ~= nil,
		summary = {
			total = if population then population.total else 0,
			cap = if population then population.cap else nil,
			free = free,
		},
		rows = rows,
		pool = {
			count = free,
			text = if free > 0 then "Carry goods · + gives them a job" else "None free: lower a job first",
		},
		soldiers = { count = byJob.soldier or 0 },
	}
end

return table.freeze(JobModel)
