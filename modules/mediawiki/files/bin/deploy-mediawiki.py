#! /usr/bin/python3
import argparse
import os
import time
import requests


repos = {'config': 'config', 'world': 'w', 'landing': 'landing', 'errorpages': 'ErrorPages'}
DEPLOYUSER = 'www-data'


def check_up(Debug=None, Host=None, domain='https://meta.miraheze.org', verify=True, force=False):
    if not Debug and not Host:
        raise Exception('Host or Debug must be specified')
    if Debug:
        headers = {'X-Miraheze-Debug': f'{Debug}.miraheze.org'}
        server = Debug
    else:
        server = 'localhost'
    if Host:
        headers = {'host': Host}
    up = False
    req = requests.get(f'{domain}/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json', headers=headers, verify=verify)
    if req.status_code == 200 and 'miraheze' in req.text and Debug and Debug in req.headers['X-Served-By']:
        up = True
    if force:
        print(f'Ignoring canary check error on {server}@{domain} due to --force')
    else:
        print(f'Canary check failed for {server}@{domain}. Aborting... - use --force to proceed')
        os.system(f'/usr/local/bin/logsalmsg DEPLOY ABORTED: Canary check failed for {server}@{domain}')
        exit(3)
    return up


def remote_sync_file(time, serverlist, path, recursive=True, force=False):
    print(f'Start {path} deploys.')
    for server in serverlist:
        print(f'Deploying {path} to {server}.')
        ec = os.system(_construct_rsync_command(time=time, local=False, dest=path, server=server, recursive=recursive))
        check_up(Debug=server, force=force)
        print(f'Deployed {path} to {server}.')
    print(f'Finished {path} deploys.')
    return ec


def _get_staging_path(repo):
    return f'/srv/mediawiki-staging/{repos[repo]}/'


def _get_deployed_path(repo):
    return f'/srv/mediawiki/{repos[repo]}/'


def _construct_rsync_command(time, dest, recursive=True, local=True, location='', server=None):
    if time:
        params = '--inplace'
    else:
        params = '--update'
    if recursive:
        params = params + ' -r --delete'
    if local:
        if location == '':
            raise Exception('Location must be specified for local rsync.')
        return f'sudo -u {DEPLOYUSER} rsync {params} --exclude=".*" {location} {dest}'
    if (location == (dest or '')) and server:  # ignore location if not specified, if given must equal dest.
        return f'sudo -u www-data rsync {params} -e "ssh -i /srv/mediawiki-staging/deploykey" {dest} www-data@{server}.miraheze.org:{dest}'
    else:
        raise Exception(f'Error constructing command. Either server was missing or {location} != {dest}')


def _construct_git_pull(repo, submodules=False):
    if submodules:
        extrap = '--recurse-submodules'
    else:
        extrap = ''
    return f'sudo -u {DEPLOYUSER} git -C {_get_staging_path(repo)} pull {extrap} --quiet'


def run(args, start):
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
    rsync = []
    rebuild = []
    postinstall = []
    stage = []
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
                stage.append(_construct_git_pull(repo, submodules=sm))
            except KeyError:
                print(f'Failed to pull {repo} due to invalid name')
    options = {'config': args.config, 'world': args.world, 'landing': args.landing, 'errorpages': args.errorpages}
    for cmd in stage:  # setup env, git pull etc
        exitcodes.append(os.system(cmd))
    for option in options:  # configure rsync & custom data for repos
        if options[option]:
            if options[option] == 'world':  # install steps for w
                os.chdir(_get_staging_path('world'))
                exitcodes.append(os.system('sudo -u www-data composer install --no-dev --quiet'))
                rebuild.append('sudo -u www-data php /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/rebuildVersionCache.php --save-gitinfo --wiki=loginwiki')
                rsyncpaths.append('/srv/mediawiki/cache/gitinfo/')
            rsync.append(_construct_rsync_command(time=args.ignoretime, location=f'{_get_staging_path(options[option])}*', dest=_get_deployed_path(options[option])))
            rsyncpaths.append(_get_deployed_path(options[option]))
    if args.files:  # specfic extra files
        files = str(args.files).split(',')
        for file in files:
            rsync.append(_construct_rsync_command(time=args.ignoretime, recursive=False, location=f'/srv/mediawiki-staging/{file}', dest=f'/srv/mediawiki/{file}'))
            rsyncfiles.append(f'/srv/mediawiki/{file}')
    if args.folders:  # specfic extra folders
        folders = str(args.folders).split(',')
        for folder in folders:
            rsync.append(_construct_rsync_command(time=args.ignoretime, location=f'/srv/mediawiki-staging/{folder}/*', dest='/srv/mediawiki/{folder}/'))
            rsyncpaths.append(f'/srv/mediawiki/{folder}/')
    
    if args.extensionlist:  # when adding skins/exts
        rebuild.append('sudo -u www-data php /srv/mediawiki/w/extensions/CreateWiki/maintenance/rebuildExtensionListCache.php --wiki=loginwiki')
        rsyncfiles.append('/srv/mediawiki/cache/extension-list.json')
    
    for cmd in rsync:  # move staged content to live
        exitcodes.append(os.system(cmd))

    # These need to be setup late because dodgy
    if args.l10nupdate:  # used by automated maint
        os.system('sudo -u www-data ionice -c idle /usr/bin/nice -n 15 /usr/bin/php /srv/mediawiki/w/extensions/LocalisationUpdate/update.php --wiki=loginwiki')  # gives garbage errors
        args.l10n = True  # imply --l10n
    if args.l10n:  # setup l10n
        postinstall.append('sudo -u www-data php /srv/mediawiki/w/maintenance/mergeMessageFileList.php --quiet --wiki=loginwiki --output /srv/mediawiki/config/ExtensionMessageFiles.php')
        rebuild.append('sudo -u www-data php /srv/mediawiki/w/maintenance/rebuildLocalisationCache.php --quiet --wiki=loginwiki')
        rsyncpaths.append('/srv/mediawiki/cache/l10n/')

    for cmd in postinstall:  # cmds to run after rsync & install (like 
        exitcodes.append(os.system(cmd))
    for cmd in rebuild:  # update ext list + l10n
        exitcodes.append(os.system(cmd))

    # see if we are online - exit code 3 if not
    check_up(Debug=None, Host='meta.miraheze.org', domain='https://localhost', verify=False, force=args.force)

    # decide what servers to remote on
    if args.servers == 'skip':
        print('Sync skipped. Mediawiki deploy has not passed canary stage.')
        sync = False
    elif args.servers == 'all':
        serverlist = ['mw8', 'mw9', 'mw10', 'mw12', 'mw13', 'mwtask1']
        sync = True
    else:
        serverlist = str(args.servers).split(',')
        sync = True

    if sync:
        for path in rsyncpaths:
            exitcodes.append(remote_sync_file(time=args.ignoretime, serverlist=serverlist, path=path, force=args.force))
        for file in rsyncfiles:
            exitcodes.append(remote_sync_file(time=args.ignoretime, serverlist=serverlist, path=file, recursive=False, force=args.force))

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
    run(parser.parse_args(), start)
