#!/usr/bin/python3

import argparse
import logging
import sys
import redis

from prometheus_client import CollectorRegistry, Gauge, write_to_textfile
from prometheus_client.exposition import generate_latest

log = logging.getLogger(__name__)


def collect_jobqueue_stats(args, registry):
    r = redis.Redis(host=args.host, port=args.port, password=args.password, decode_responses=True)

    queues = [
        'l-unclaimed',
        'z-abandoned'
    ]

    jobs = [
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
        'DeleteTranslatableBundleJob',
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
        'MoveTranslatableBundleJob',
        'NamespaceMigrationJob',
        'PageProperties',
        'parsoidCachePrewarm',
        'PublishStashedFile',
        'PurgeEntityData',
        'RecordLintJob',
        'RemovePIIJob',
        'RenderTranslationPageJob',
        'RequestWikiAIJob',
        'SetContainersAccessJob',
        'SMW\\ChangePropagationClassUpdateJob',
        'SMW\\ChangePropagationDispatchJob',
        'SMW\\ChangePropagationUpdateJob',
        'SMW\\EntityIdDisposerJob',
        'SMW\\FulltextSearchTableRebuildJob',
        'SMW\\FulltextSearchTableUpdateJob',
        'SMW\\PropertyStatisticsRebuildJob',
        'SMW\\RefreshJob',
        'SMW\\UpdateDispatcherJob',
        'SMW\\UpdateJob',
        'SMWRefreshJob',
        'SMWUpdateJob',
        'TTMServerMessageUpdateJob',
        'ThumbnailRender',
        'TranslatableBundleDeleteJob',
        'TranslatableBundleMoveJob',
        'TranslateRenderJob',
        'TranslateSandboxEmailJob',
        'TranslationNotificationsEmailJob',
        'TranslationNotificationsSubmitJob',
        'TranslationsUpdateJob',
        'UpdateMessageBundle',
        'UpdateRepoOnDelete',
        'UpdateRepoOnMove',
        'UpdateTranslatablePageJob',
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
        'menteeOverviewUpdateDataForMentor',
        'newUserMessageJob',
        'newcomerTasksCacheRefreshJob',
        'null',
        'pageFormsCreatePage',
        'pageSchemasCreatePage',
        'reassignMenteesJob',
        'recentChangesUpdate',
        'refreshLinks',
        'refreshLinksDynamic',
        'refreshLinksPrioritized',
        'renameUser',
        'revertedTagUpdate',
        'sendMail',
        'setUserMentorDatabaseJob',
        'smw.changePropagationClassUpdate',
        'smw.changePropagationDispatch',
        'smw.changePropagationUpdate',
        'smw.deferredConstraintCheckUpdateJob',
        'smw.elasticFileIngest',
        'smw.elasticIndexerRecovery',
        'smw.entityIdDisposer',
        'smw.fulltextSearchTableRebuild',
        'smw.fulltextSearchTableUpdate',
        'smw.parserCachePurgeJob',
        'smw.propertyStatisticsRebuild',
        'smw.refresh',
        'smw.update',
        'smw.updateDispatcher',
        'updateBetaFeaturesUserCounts',
        'userEditCountInit',
        'userGroupExpiry',
        'userOptionsUpdate',
        'watchlistExpiry',
        'webVideoTranscode',
        'webVideoTranscodePrioritized',
        'wikibase-InjectRCRecords',
        'wikibase-addUsagesForPage'
    ]

    jobqueue_stats = {}

    jobqueue_stats['jobs'] = Gauge(
        'jobs', 'Jobs', ['key'],
        namespace='jobqueue', registry=registry)

    for job in jobs:
        for queue in queues:
            lsum = 0
            lkeys = r.keys( f"*:jobqueue:{job}:{queue}" )
            for lkey in lkeys:
                if not 'l-unclaimed' in lkey:
                    lsum = lsum + int(r.zcard( lkey ))
                else:
                    lsum = lsum + int(r.llen( lkey ))
            jobqueue_stats['jobs'].labels(key = f"{job}-{queue}").set(lsum)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--outfile', metavar='FILE.prom',
                        help='Output file (stdout)')
    parser.add_argument('--host', metavar='HOST',
                        help='Hostname or ip for redis host (%(default)s)',
                        default='localhost')
    parser.add_argument('--port', metavar='PORT', type=int,
                        help='The port for redis host (%(default)s)',
                        default=6379)
    parser.add_argument('--password', metavar='PASSWORD', type=str, required=True,
                        help='Password for redis',)
    parser.add_argument('-d', '--debug', action='store_true',
                        help='Enable debug logging (false)')
    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.WARNING)

    if args.outfile and not args.outfile.endswith('.prom'):
        parser.error('Output file does not end with .prom')

    registry = CollectorRegistry()
    collect_jobqueue_stats(args, registry)

    if args.outfile:
        write_to_textfile(args.outfile, registry)
    else:
        sys.stdout.write(generate_latest(registry).decode('utf-8'))


if __name__ == '__main__':
    sys.exit(main())
