#! /usr/bin/python3

import argparse
from typing import Optional, Union  # Use TypedDict too
import os
import time
import requests
import socket
from sys import exit


repos = {'config': 'config', 'world': 'w', 'landing': 'landing', 'errorpages': 'ErrorPages'}
DEPLOYUSER = 'www-data'
ENVIRONMENTS = {
    'beta': {
        'wikidbname': 'betawiki',
        'wikiurl': 'beta.betaheze.org',
        'servers': [],
        'canary': 'test101',
    },
    'prod': {
        'wikidbname': 'testwiki',  # don't use loginwiki anymore - we want this to be an experimental wiki
        'wikiurl': 'publictestwiki.com',
        'servers': ['mw101', 'mw102', 'mw111', 'mw112', 'mw121', 'mw122'],
        'canary': 'mwtask111',
    },
}
HOSTNAME = socket.gethostname()


def get_environment_info() -> dict[str, list[str]]:
    if HOSTNAME.split('.')[0].startswith('test'):
        return ENVIRONMENTS['beta']  # type: ignore
    return ENVIRONMENTS['prod']  # type: ignore


def get_server_list(envinfo: dict[str, list[str]], servers: str) -> list[str]:
    if servers in ('all', 'scsvg'):
        slist = envinfo['servers']
        slist.append(envinfo['canary'])  # type: ignore
        return slist
    if servers == 'skip':
        return [envinfo['canary']]  # type: ignore
    return servers.split(',')


def run_command(cmd: str) -> int:
    start = time.time()
    print(f'Execute: {cmd}')
    ec = os.system(cmd)
    print(f'Completed ({ec}) in {str(int(time.time() - start))}s!')
    return ec


def non_zero_code(ec: list[int], nolog: bool = True, leave: bool = True) -> bool:
    for code in ec:
        if code != 0:
            if not nolog:
                os.system('/usr/bin/logsalmsg DEPLOY ABORTED: Non-Zero Exit Code in prep, see output.')
            if leave:
                print('Exiting due to non-zero status.')
                exit(1)
            return True
    return False


def check_up(nolog: bool, Debug: Optional[str] = None, Host: Optional[str] = None, domain: str = 'meta.miraheze.org', verify: bool = True, force: bool = False) -> bool:
    if not Debug and not Host:
        raise Exception('Host or Debug must be specified')
    if Debug:
        server = f'{Debug}.miraheze.org'
        headers = {'X-Miraheze-Debug': server}
        location = f'{domain}@{server}'
    else:
        os.environ['NO_PROXY'] = 'localhost'
        domain = 'localhost'
        headers = {'host': f'{Host}'}
        location = f'{Host}@{domain}'
    up = False
    req = requests.get(f'https://{domain}/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json', headers=headers, verify=verify)
    if req.status_code == 200 and 'miraheze' in req.text and (Debug is None or Debug in req.headers['X-Served-By']):
        up = True
    if not up:
        print(f'Status: {req.status_code}')
        print(f'Text: {"miraheze" in req.text} \n {req.text}')
        print(f'Debug: {(Debug is None or Debug in req.headers["X-Served-By"])}')
        if force:
            print(f'Ignoring canary check error on {location} due to --force')
        else:
            print(f'Canary check failed for {location}. Aborting... - use --force to proceed')
            message = f'/usr/local/bin/logsalmsg DEPLOY ABORTED: Canary check failed for {location}'
            if nolog:
                print(message)
            else:
                os.system(message)
            exit(3)
    return up


def remote_sync_file(time: str, serverlist: list[str], path: str, envinfo: dict[str, list[str]], nolog: bool, recursive: bool = True, force: bool = False) -> int:
    print(f'Start {path} deploys.')
    for server in serverlist:
        if envinfo['canary'] != server.split('.')[0]:
            print(f'Deploying {path} to {server}.')
            ec = run_command(_construct_rsync_command(time=time, local=False, dest=path, server=server, recursive=recursive))
            check_up(Debug=server, force=force, domain=envinfo['wikiurl'], nolog=nolog)  # type: ignore
            print(f'Deployed {path} to {server}.')
        else:
            return 0
    print(f'Finished {path} deploys.')
    return ec


def _get_staging_path(repo: str) -> str:
    return f'/srv/mediawiki-staging/{repos[repo]}/'


def _get_deployed_path(repo: str) -> str:
    return f'/srv/mediawiki/{repos[repo]}/'


def _construct_rsync_command(time: str, dest: str, recursive: bool = True, local: bool = True, location: Union[None, str] = None, server: Union[None, str] = None) -> str:
    if time:
        params = '--inplace'
    else:
        params = '--update'
    if recursive:
        params = params + ' -r --delete'
    if local:
        if location is None:
            raise Exception('Location must be specified for local rsync.')
        return f'sudo -u {DEPLOYUSER} rsync {params} --exclude=".*" {location} {dest}'
    if location is None:
        location = dest
    if location == dest and server:  # ignore location if not specified, if given must equal dest.
        return f'sudo -u {DEPLOYUSER} rsync {params} -e "ssh -i /srv/mediawiki-staging/deploykey" {dest} {DEPLOYUSER}@{server}.miraheze.org:{dest}'
    # a return None here would be dangerous - except and ignore R503 as return after Exception is not reachable
    raise Exception(f'Error constructing command. Either server was missing or {location} != {dest}')  # noqa: R503


def _construct_git_pull(repo: str, submodules: bool = False) -> str:
    if submodules:
        extrap = '--recurse-submodules'
    else:
        extrap = ''
    return f'sudo -u {DEPLOYUSER} git -C {_get_staging_path(repo)} pull {extrap} --quiet'


def run(args: argparse.Namespace, start: float) -> None:
    envinfo = get_environment_info()
    servers = get_server_list(envinfo, args.servers)
    options = {'config': args.config, 'world': args.world, 'landing': args.landing, 'errorpages': args.errorpages}
    exitcodes = []
    loginfo = {}
    rsyncpaths = []
    rsyncfiles = []
    rsync = []
    rebuild = []
    postinstall = []
    stage = []
    for arg in vars(args).items():
        if arg[1] is not None and arg[1] is not False:
            loginfo[arg[0]] = arg[1]
    synced = loginfo['servers']
    if envinfo['canary'] in servers:
        del loginfo['servers']
        text = f'starting deploy of "{str(loginfo)}" to {synced}'
        if not args.nolog:
            os.system(f'/usr/local/bin/logsalmsg {text}')
        else:
            print(text)
        pull = []
        if args.world and not args.pull:
            pull = ['world']
        if args.pull:
            pull = str(args.pull).split(',')
        if args.world and 'world' not in pull:
            pull.append('world')
        if pull:
            for repo in pull:
                if repo == 'world':
                    sm = True
                else:
                    sm = False
                try:
                    stage.append(_construct_git_pull(repo, submodules=sm))
                except KeyError:
                    print(f'Failed to pull {repo} due to invalid name')

        for cmd in stage:  # setup env, git pull etc
            exitcodes.append(run_command(cmd))
        non_zero_code(exitcodes, nolog=args.nolog)
        for option in options:  # configure rsync & custom data for repos
            if options[option]:
                if option == 'world':  # install steps for w
                    os.chdir(_get_staging_path('world'))
                    exitcodes.append(run_command(f'sudo -u {DEPLOYUSER} composer install --no-dev --quiet'))
                    rebuild.append(f'sudo -u {DEPLOYUSER} php /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/rebuildVersionCache.php --save-gitinfo --wiki={envinfo["wikidbname"]}')
                    rsyncpaths.append('/srv/mediawiki/cache/gitinfo/')
                rsync.append(_construct_rsync_command(time=args.ignoretime, location=f'{_get_staging_path(option)}*', dest=_get_deployed_path(option)))
        non_zero_code(exitcodes, nolog=args.nolog)
        if args.files:  # specfic extra files
            files = str(args.files).split(',')
            for file in files:
                rsync.append(_construct_rsync_command(time=args.ignoretime, recursive=False, location=f'/srv/mediawiki-staging/{file}', dest=f'/srv/mediawiki/{file}'))
        if args.folders:  # specfic extra folders
            folders = str(args.folders).split(',')
            for folder in folders:
                rsync.append(_construct_rsync_command(time=args.ignoretime, location=f'/srv/mediawiki-staging/{folder}/*', dest='/srv/mediawiki/{folder}/'))

        if args.extensionlist:  # when adding skins/exts
            rebuild.append(f'sudo -u www-data php /srv/mediawiki/w/extensions/CreateWiki/maintenance/rebuildExtensionListCache.php --wiki={envinfo["wikidbname"]}')

        for cmd in rsync:  # move staged content to live
            exitcodes.append(run_command(cmd))
        non_zero_code(exitcodes)
        # These need to be setup late because dodgy
        if args.l10nupdate:  # used by automated maint
            run_command(f'sudo -u www-data ionice -c idle /usr/bin/nice -n 15 /usr/bin/php /srv/mediawiki/w/extensions/LocalisationUpdate/update.php --quiet --wiki={envinfo["wikidbname"]}')  # gives garbage errors
            args.l10n = True  # imply --l10n
        if args.l10n:  # setup l10n
            postinstall.append(f'sudo -u www-data php /srv/mediawiki/w/maintenance/mergeMessageFileList.php --quiet --wiki={envinfo["wikidbname"]} --output /srv/mediawiki/config/ExtensionMessageFiles.php')
            rebuild.append(f'sudo -u www-data php /srv/mediawiki/w/maintenance/rebuildLocalisationCache.php --quiet --wiki={envinfo["wikidbname"]}')

        for cmd in postinstall:  # cmds to run after rsync & install (like mergemessage)
            exitcodes.append(run_command(cmd))
        non_zero_code(exitcodes, nolog=args.nolog)
        for cmd in rebuild:  # update ext list + l10n
            exitcodes.append(run_command(cmd), nolog=args.nolog)
        non_zero_code(exitcodes, nolog=args.nolog)

        # see if we are online - exit code 3 if not
        check_up(Debug=None, Host=envinfo['wikiurl'], verify=False, force=args.force, nolog=args.nolog)  # type: ignore

    # actually set remote lists
    for option in options:
        if options[option]:
            rsyncpaths.append(_get_deployed_path(option))
    if args.files:
        for file in str(args.files).split(','):
            rsyncfiles.append(f'/srv/mediawiki/{file}')
    if args.folders:
        for folder in str(args.folders).split(','):
            rsyncfiles.append(f'/srv/mediawiki/{folder}/')
    if args.extensionlist:
        rsyncfiles.append('/srv/mediawiki/cache/extension-list.json')
    if args.l10n:
        rsyncpaths.append('/srv/mediawiki/cache/l10n/')

    for path in rsyncpaths:
        exitcodes.append(remote_sync_file(time=args.ignoretime, serverlist=servers, path=path, force=args.force, envinfo=envinfo, nolog=args.nolog))
    for file in rsyncfiles:
        exitcodes.append(remote_sync_file(time=args.ignoretime, serverlist=servers, path=file, recursive=False, force=args.force, envinfo=envinfo, nolog=args.nolog))

    fintext = f'finished deploy of "{str(loginfo)}" to {synced}'

    failed = non_zero_code(ec=exitcodes, leave=False)
    if failed:
        fintext += f' - FAIL: {exitcodes}'
    else:
        fintext += ' - SUCCESS'
    fintext += f' in {str(int(time.time() - start))}s'
    if not args.nolog:
        os.system(f'/usr/local/bin/logsalmsg {fintext}')
    else:
        print(fintext)
    if failed:
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
