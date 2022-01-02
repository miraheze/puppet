#! /usr/bin/python3
import argparse
import os
import time
import requests


repos = {'config': 'config', 'world': 'w', 'landing': 'landing', 'errorpages': 'ErrorPages'}


def check_up(server):
    up = False
    headers = {'X-Miraheze-Debug': f'{server}.miraheze.org'}
    req = requests.get('https://meta.miraheze.org/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json', headers=headers)
    if req.status_code == 200 and 'miraheze' in req.text and server in req.headers['X-Served-By']:
        up = True
    return up


def _get_staging_path(repo):
    return f'/srv/mediawiki-staging/{repos[repo]}/'


def _get_deployed_path(repo):
    return f'/srv/mediawiki/{repos[repo]}/'


def _construct_git_pull(repo, submodules=False):
    if submodules:
        extrap = '--recurse-submodules'
    else:
        extrap = ''
    return f'sudo -u www-data git -C {_get_staging_path(repo)} pull {extrap} --quiet'


def run(args, start):
    if args.ignoretime:
        rsyncparams = '--inplace'
    else:
        rsyncparams = '--update'
    loginfo = {}
    exitcodes = []
    for arg in vars(args).items():
        if arg[1] is not None and arg[1] is not False:
            loginfo[arg[0]] = arg[1]
    synced = loginfo['servers']
    del loginfo['servers']
    text = f'starting deploy of "{str(loginfo)}" to {synced}'
    rsyncpaths = []
    rsyncfiles = []
    if not args.nolog:
        os.system(f'/usr/local/bin/logsalmsg {text}')
    else:
        print(text)
    if args.world and not args.pull:
        pull = ['world']
    if args.pull or args.world:
        if args.pull:
            pull = str(args.pull).split(',')
        elif args.world and 'world' not in pull:
            pull.append('world')
        for repo in pull:
            if repo == 'world':
                sm = True
            else:
                sm = False
            try:
                exitcodes.append(os.system(_construct_git_pull(repo, submodules=sm)))
            except KeyError:
                print(f'Failed to pull {repo} due to invalid name')
    if args.config:
        exitcodes.append(os.system(f'sudo -u www-data rsync -r --delete {rsyncparams} --exclude=".*" {_get_staging_path("config")}* {_get_deployed_path("config")}'))
        rsyncpaths.append(_get_deployed_path('config'))
    if args.world:
        if args.proxy:
            proxy = 'http_proxy=http://bast101.miraheze.org:8080'  # read git config you stupid software
        os.chdir(_get_staging_path('world'))
        exitcodes.append(os.system(f'sudo -u www-data {proxy} composer install --no-dev --quiet'))
        exitcodes.append(os.system('sudo -u www-data php /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/rebuildVersionCache.php --save-gitinfo --wiki=loginwiki'))
        exitcodes.append(os.system(f'sudo -u www-data rsync -r --delete {rsyncparams} --exclude=".*" {_get_staging_path("world")}* {_get_deployed_path("world")}'))
        rsyncpaths.append(_get_deployed_path('world'))
        rsyncpaths.append('/srv/mediawiki/cache/gitinfo/')
    if args.landing:
        exitcodes.append(os.system(f'sudo -u www-data rsync -r --delete {rsyncparams} --exclude=".*" {_get_staging_path("landing")}* {_get_deployed_path("landing")}'))
        rsyncpaths.append(_get_deployed_path('landing'))
    if args.errorpages:
        exitcodes.append(os.system(f'sudo -u www-data rsync -r --delete {rsyncparams} --exclude=".*" {_get_staging_path("errorpages")}* {_get_deployed_path("errorpages")}'))
        rsyncpaths.append(_get_deployed_path('errorpages'))
    if args.files:
        files = str(args.files).split(',')
        for file in files:
            exitcodes.append(os.system(f'sudo -u www-data rsync {rsyncparams} /srv/mediawiki-staging/{file} /srv/mediawiki/{file}'))
            rsyncfiles.append(f'/srv/mediawiki/{file}')
    if args.folders:
        folders = str(args.folders).split(',')
        for folder in folders:
            exitcodes.append(os.system(f'sudo -u www-data rsync -r --delete {rsyncparams} --exclude=".*" /srv/mediawiki-staging/{folder}/* /srv/mediawiki/{folder}/'))
            rsyncpaths.append(f'/srv/mediawiki/{folder}/')
    if args.l10nupdate:
        exitcodes.append(os.system('sudo -u www-data ionice -c idle /usr/bin/nice -n 15 /usr/bin/php /srv/mediawiki/w/extensions/LocalisationUpdate/update.php --wiki=loginwiki'))
        args.l10n = True
    if args.l10n:
        exitcodes.append(os.system('sudo -u www-data php /srv/mediawiki/w/maintenance/mergeMessageFileList.php --quiet --wiki=loginwiki --output /srv/mediawiki/config/ExtensionMessageFiles.php'))
        exitcodes.append(os.system('sudo -u www-data php /srv/mediawiki/w/maintenance/rebuildLocalisationCache.php --quiet --wiki=loginwiki'))
        rsyncpaths.append('/srv/mediawiki/cache/l10n/')
    if args.extensionlist:
        exitcodes.append(os.system('sudo -u www-data php /srv/mediawiki/w/extensions/CreateWiki/maintenance/rebuildExtensionListCache.php --wiki=loginwiki'))
        rsyncfiles.append('/srv/mediawiki/cache/extension-list.json')
    if args.servers == 'all':
        args.servers = 'ovlon'  # ovlon is active now
    if args.servers == 'ovlon':
        serverlist = ['mw8', 'mw9', 'mw10', 'mw12', 'mw13', 'mwtask1']
        sync = True
    elif args.servers == 'scsvg':
        serverlist = ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122']
        sync = True
    elif args.servers == 'skip':
        print('Sync skipped. Mediawiki deploy has not passed canary stage.')
        sync = False
    else:
        serverlist = str(args.servers).split(',')
        sync = True
    up = False
    headers = {'host': 'meta.miraheze.org'}
    os.environ['NO_PROXY'] = 'localhost'
    req = requests.get('https://localhost/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json', headers=headers, verify=False)
    if req.status_code == 200 and 'miraheze' in req.text:
        up = True
    if not up:
        if args.force:
            print('Ignoring canary error due to --force')
        else:
            print('Canary check failed for localhost. Aborting... - use --force to proceed')
            os.system('/usr/local/bin/logsalmsg DEPLOY ABORTED: Canary check failed for localhost')
            exit(3)
    if sync:
        if len(rsyncpaths) > 0:
            for path in rsyncpaths:
                print(f'Start {path} deploys.')
                for server in serverlist:
                    print(f'Deploying {path} to {server}.')
                    exitcodes.append(os.system(f'sudo -u www-data rsync -r --delete -r {rsyncparams} -e "ssh -i /srv/mediawiki-staging/deploykey" {path} www-data@{server}.miraheze.org:{path}'))
                    if not check_up(server):
                        print(f'Canary check failed for {server}. Aborting... - use --force to proceed')
                        if not args.force:
                            os.system(f'/usr/local/bin/logsalmsg DEPLOY ABORTED: Canary check failed for {server}')
                            exit(3)
                        else:
                            print('Ignoring canary error due to --force')
                    print(f'Deployed {path} to {server}.')
                print(f'Finished {path} deploys.')
        if len(rsyncfiles) > 0:
            for file in rsyncfiles:
                print(f'Start {file} deploys.')
                for server in serverlist:
                    print(f'Deploying {file} to {server}.')
                    exitcodes.append(os.system(f'sudo -u www-data rsync {rsyncparams} -e "ssh -i /srv/mediawiki-staging/deploykey" {file} www-data@{server}.miraheze.org:{file}'))
                    if not check_up(server):
                        print(f'Canary check failed for {server}. Aborting... - use --force to proceed')
                        if not args.force:
                            os.system(f'/usr/local/bin/logsalmsg DEPLOY ABORTED: Canary check failed for {server}')
                            exit(3)
                        else:
                            print('Ignoring canary error due to --force')
                    print(f'Deployed {file} to {server}.')

    fintext = f'finished deploy of "{str(loginfo)}" to {synced}'
    FAIL = 0
    for code in exitcodes:
        if code != 0:
            FAIL = 1
    timetaken = int(time.time() - start)
    if FAIL == 1:
        fintext = f'{fintext} - FAIL: {exitcodes}'
    else:
        fintext = f'{fintext} - SUCCESS'
    if not args.nolog:
        os.system(f'/usr/local/bin/logsalmsg {fintext} in {str(timetaken)}s')
    else:
        print(f'{fintext} in {str(timetaken)}s')
    if FAIL == 1:
        exit(1)


if __name__ == '__main__':
    start = time.time()
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('--pull', dest='pull')
    parser.add_argument('--config', dest='config', action='store_true')
    parser.add_argument('--world', dest='world', action='store_true')
    parser.add_argument('--landing', dest='landing', action='store_true')
    parser.add_argument('--errorpages', dest='errorpages', action='store_true')
    parser.add_argument('--l10nupdate', dest='l10nupdate', action='store_true')
    parser.add_argument('--l10n', dest='l10n', action='store_true')
    parser.add_argument('--extension-list', dest='extensionlist', action='store_true')
    parser.add_argument('--no-log', dest='nolog', action='store_true')
    parser.add_argument('--force', dest='force', action='store_true')
    parser.add_argument('--files', dest='files')
    parser.add_argument('--folders', dest='folders')
    parser.add_argument('--servers', dest='servers', required=True)
    parser.add_argument('--ignore-time', dest='ignoretime', action='store_true')
    parser.add_argument('--use-proxy', dest='proxy', action='store_true')
    run(parser.parse_args(), start)
