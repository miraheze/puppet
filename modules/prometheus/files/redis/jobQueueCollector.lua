-- JobQueue additional metric collector
-- Author: John Lewis, Miraheze

local result = {}
local queues = { 'l-unclaimed', 'z-abandoned' }
-- Below is a list of jobs we want to monitor specifically
local jobs = { '*', 'CreateWikiJob', 'RequestWikiAIJob', 'DataDumpGenerateJob', 'MWScriptJob', 'NamespaceMigrationJob', 'LocalRenameUserJob', 'LocalGlobalUserPageCacheUpdateJob', 'replaceText', 'webVideoTranscode', 'refreshLinks', 'htmlCacheUpdate', 'recentChangesUpdate' }

for _,job in ipairs(jobs) do
	for _,queue in ipairs(queues) do
		local lsum = 0
		local lkeys = redis.call( 'KEYS', 'global:jobqueue:' .. job .. ':' .. queue )
		for _,lkey in ipairs(lkeys) do
			if queue ~= 'l-unclaimed' then
				lsum = lsum + tonumber(redis.call('ZCARD', lkey))
			else
				lsum = lsum + tonumber(redis.call('LLEN', lkey))
			end
		end
		table.insert(result, job .. '-' .. queue )
		table.insert(result, tostring(lsum) )
	end
end

return result
