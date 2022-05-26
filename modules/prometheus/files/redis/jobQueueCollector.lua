-- JobQueue additional metric collector
-- Author: John Lewis, Miraheze

local result = {}
local queues = { 'l-unclaimed', 'z-abandoned' }

-- Below is a list of jobs we want to monitor specifically
local jobs = {
	'*',
	'AssembleUploadChunks',
	'CentralAuthCreateLocalAccountJob',
	'CentralAuthUnattachUserJob',
	'ChangeDeletionNotification',
	'ChangeNotification',
	'ChangeVisibilityNotification',
	'CleanTermsIfUnused',
	'CreateWikiJob',
	'DataDumpGenerateJob',
	'DeleteJob',
	'DispatchChangeDeletionNotification',
	'DispatchChangeVisibilityNotification',
	'DispatchChanges',
	'EchoNotificationDeleteJob',
	'EchoNotificationJob',
	'EchoPushNotificationRequest',
	'EntityChangeNotification',
	'GlobalNewFilesDeleteJob',
	'GlobalNewFilesInsertJob',
	'GlobalNewFilesMoveJob',
	'GlobalUserPageLocalJobSubmitJob',
	'InitImageDataJob',
	'LocalGlobalUserPageCacheUpdateJob',
	'LocalPageMoveJob',
	'LocalRenameUserJob',
	'LoginNotifyChecks',
	'MDCreatePage',
	'MDDeletePage',
	'MWScriptJob',
	'MassMessageJob',
	'MassMessageServerSideJob',
	'MassMessageSubmitJob',
	'MessageGroupStatesUpdaterJob',
	'MessageGroupStatsRebuildJob',
	'MessageIndexRebuildJob',
	'MessageUpdateJob',
	'NamespaceMigrationJob',
	'PublishStashedFile',
	'PurgeEntityData',
	'RecordLintJob',
	'RemovePIIJob',
	'RenderJob',
	'RequestWikiAIJob',
	'TTMServerMessageUpdateJob',
	'ThumbnailRender',
	'TranslatableBundleMoveJob',
	'TranslatablePageMoveJob',
	'TranslateDeleteJob',
	'TranslateRenderJob',
	'TranslationsUpdateJob',
	'UpdateMessageBundle',
	'UpdateRepoOnDelete',
	'UpdateRepoOnMove',
	'UpdateTranslatorActivity',
	'activityUpdateJob',
	'cargoPopulateTable',
	'categoryMembershipChange',
	'cdnPurge',
	'clearUserWatchlist',
	'clearWatchlistNotifications',
	'compileArticleMetadata',
	'constraintsRunCheck',
	'constraintsTableUpdate',
	'crosswikiSuppressUser',
	'deleteLinks',
	'deletePage',
	'dtImport',
	'edReparse',
	'enotifNotify',
	'enqueue',
	'fixDoubleRedirect',
	'flaggedrevs_CacheUpdate',
	'globalUsageCachePurge',
	'htmlCacheUpdate',
	'null',
	'pageFormsCreatePage',
	'pageSchemasCreatePage',
	'recentChangesUpdate',
	'refreshLinks',
	'refreshLinksDynamic',
	'refreshLinksPrioritized',
	'renameUser',
	'replaceText',
	'revertedTagUpdate',
	'sendMail',
	'updateBetaFeaturesUserCounts',
	'userEditCountInit',
	'userGroupExpiry',
	'userOptionsUpdate',
	'watchlistExpiry',
	'webVideoTranscode',
	'webVideoTranscodePrioritized',
	'wikibase-InjectRCRecords',
	'wikibase-addUsagesForPage'
}

for _,job in ipairs(jobs) do
	for _,queue in ipairs(queues) do
		local lsum = 0
		local lkeys = redis.call( 'KEYS', '*:jobqueue:' .. job .. ':' .. queue )
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
