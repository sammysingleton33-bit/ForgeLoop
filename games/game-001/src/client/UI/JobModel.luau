--!strict
--[[
	UI/JobModel — the job panel (FL-0065, Kingdom panel "Jobs" tab) as data, pure. Counts come only
	from the server's population (Kingdom.Population / Kingdom.GetPopulation: my kingdom's
	CitizenService:getPopulation { total, byJob, cap, quotas? }); a change is a request
	(Kingdom.SetJobQuota(job, count) → (boolean, errorCode?)) that sets the job's quota, which the
	server fills from the hauler pool about once a second.

	Every request steps from the job's newest target, not from the count (FORGE-05 M1 on #55): three
	quick + send 4, 5, 6, not 4 three times. The target is, newest first: the request on its way, the
	server's `quotas[job]` when the payload carries it, the quota this client last had acknowledged,
	the count. Adds still to be filled are reserved against the free pool, so + stops when the pool is
	spoken for.

	JobModel.JOBS                           quota jobs in panel order (FORGE-01 config Jobs.jobOrder
	                                        without the hauler pool): { id, name, sub, icon }
	JobModel.target(population, state, job) -> number     the job's newest target
	JobModel.freeLeft(population, state) -> number        free citizens not yet promised to a job
	JobModel.view(population?, state?) -> View
		state = { pending = { [job]: target }, quota = { [job]: target } }
		View = { known: boolean,
		         summary = { total, cap?, free },
		         rows = { { id, name, sub, icon, count, target, note?, busy, canAdd, canRemove } },
		         pool = { count, text },            the hauler pool, shown as "Free citizens"
		         soldiers = { count } }
	JobModel.MAX_QUOTA                       50 (G8: SetJobQuota count is integer(0, 50))
]]

local JobModel = {}

JobModel.MAX_QUOTA = 50

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

function JobModel.target(population: any, state: any, job: string): number
	local pending = state and state.pending and state.pending[job]
	if pending ~= nil then
		return pending
	end
	local server = population and population.quotas and population.quotas[job]
	if type(server) == "number" then
		return server
	end
	local acknowledged = state and state.quota and state.quota[job]
	if acknowledged ~= nil then
		return acknowledged
	end
	return if population then population.byJob[job] or 0 else 0
end

function JobModel.freeLeft(population: any, state: any): number
	if population == nil then
		return 0
	end
	local free = population.byJob.hauler or 0
	for _, job in JobModel.JOBS do
		local promised = JobModel.target(population, state, job.id) - (population.byJob[job.id] or 0)
		if promised > 0 then
			free -= promised
		end
	end
	return free
end

function JobModel.view(population: any, state: any): any
	local byJob = if population then population.byJob else {}
	local pending = if state and state.pending then state.pending else {}
	local free = byJob.hauler or 0
	local left = JobModel.freeLeft(population, state)
	local rows = {}
	for _, job in JobModel.JOBS do
		local count = byJob[job.id] or 0
		local target = JobModel.target(population, state, job.id)
		local busy = pending[job.id] ~= nil
		local note = nil
		if busy then
			note = `Asking… {count} → {target}`
		elseif target > count and free <= 0 then
			note = `Waiting for a free citizen · {count} → {target}`
		elseif target ~= count then
			note = `Moving… {count} → {target}`
		end
		table.insert(rows, {
			id = job.id,
			name = job.name,
			sub = job.sub,
			icon = job.icon,
			count = count,
			target = target,
			note = note,
			busy = busy,
			canAdd = population ~= nil and not busy and left > 0 and target < JobModel.MAX_QUOTA,
			canRemove = population ~= nil and not busy and target > 0,
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
			text = if left > 0 then "Carry goods · + hires one" else "None free: lower a job",
		},
		soldiers = { count = byJob.soldier or 0 },
	}
end

return table.freeze(JobModel)
