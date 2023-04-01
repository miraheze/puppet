#! /usr/bin/python3

import argparse
from typing import TypedDict
import os
import time
import requests
import socket
from sys import exit
from langcodes import tag_is_valid


repos = {'config': 'config', 'world': 'w', 'landing': 'landing', 'errorpages': 'ErrorPages'}
DEPLOYUSER = 'www-data'


class Environment(TypedDict):
    wikidbname: str
    wikiurl: str
    servers: list


class EnvironmentList(TypedDict):
    beta: Environment
    prod: Environment


beta: Environment = {
    'wikidbname': 'betawiki',
    'wikiurl': 'beta.betaheze.org',
    'servers': ['test131'],
}
prod: Environment = {
    'wikidbname': 'testwiki',  # don't use loginwiki anymore - we want this to be an experimental wiki
    'wikiurl': 'publictestwiki.com',
    'servers': ['mw121', 'mw122', 'mw131', 'mw132', 'mw141', 'mw142', 'mwtask141'],
}
ENVIRONMENTS: EnvironmentList = {
    'beta': beta,
    'prod': prod,
}
del beta
del prod
HOSTNAME = socket.gethostname().split('.')[0]


def get_environment_info() -> Environment:
    if HOSTNAME.startswith('test'):
        return ENVIRONMENTS['beta']
    return ENVIRONMENTS['prod']


def get_server_list(envinfo: Environment, servers: str) -> list[str]:
    if servers in ('all', 'scsvg'):
        return envinfo['servers']
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
                os.system('/usr/local/bin/logsalmsg DEPLOY ABORTED: Non-Zero Exit Code in prep, see output.')
            if leave:
                print('Exiting due to non-zero status.')
                exit(1)
            return True
    return False


def check_up(nolog: bool, Debug: str | None = None, Host: str | None = None, domain: str = 'meta.miraheze.org', verify: bool = True, force: bool = False, port: int = 443) -> bool:
    if verify is False:
        os.environ['PYTHONWARNINGS'] = 'ignore:Unverified HTTPS request'
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
    if port == 443:
        proto = 'https://'
    else:
        proto = 'http://'
    req = requests.get(f'{proto}{domain}:{port}/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json', headers=headers, verify=verify)
    if req.status_code == 200 and 'miraheze' in req.text and (Debug is None or Debug in req.headers['X-Served-By']):
        up = True
    if not up:
        print(f'Status: {req.status_code}')
        print(f'Text: {"miraheze" in req.text} \n {req.text}')
        if 'X-Served-By' not in req.headers:
            req.headers['X-Served-By'] = 'None'
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


def remote_sync_file(time: str, serverlist: list[str], path: str, envinfo: Environment, nolog: bool, recursive: bool = True, force: bool = False) -> int:
    print(f'Start {path} deploys.')
    for server in serverlist:
        if HOSTNAME != server.split('.')[0]:
            print(f'Deploying {path} to {server}.')
            ec = run_command(_construct_rsync_command(time=time, local=False, dest=path, server=server, recursive=recursive))
            check_up(Debug=server, force=force, domain=envinfo['wikiurl'], nolog=nolog)
            print(f'Deployed {path} to {server}.')
        else:
            return 0
    print(f'Finished {path} deploys.')
    return ec


def _get_staging_path(repo: str) -> str:
    return f'/srv/mediawiki-staging/{repos[repo]}/'


def _get_deployed_path(repo: str) -> str:
    return f'/srv/mediawiki/{repos[repo]}/'


def _construct_rsync_command(time: str, dest: str, recursive: bool = True, local: bool = True, location: str | None = None, server: str | None = None) -> str:
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


def _construct_git_pull(repo: str, submodules: bool = False, branch: str | None = None) -> str:
    extrap = ' '
    if submodules:
        extrap += '--recurse-submodules '

    if branch:
        extrap += f'origin {branch} '

    return f'sudo -u {DEPLOYUSER} git -C {_get_staging_path(repo)} pull{extrap}--quiet'


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
    if HOSTNAME in servers:
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
                    stage.append(_construct_git_pull(repo, submodules=sm, branch=args.branch))
                except KeyError:
                    print(f'Failed to pull {repo} due to invalid name')

        for cmd in stage:  # setup env, git pull etc
            exitcodes.append(run_command(cmd))
        non_zero_code(exitcodes, nolog=args.nolog)
        for option in options:  # configure rsync & custom data for repos
            if options[option]:
                if option == 'world':  # install steps for w
                    os.chdir(_get_staging_path('world'))
                    exitcodes.append(run_command(f'sudo -u {DEPLOYUSER} http_proxy=http://bast.miraheze.org:8080 composer install --no-dev --quiet'))
                    rebuild.append(f'sudo -u {DEPLOYUSER} MW_INSTALL_PATH=/srv/mediawiki-staging/w php /srv/mediawiki-staging/w/extensions/MirahezeMagic/maintenance/rebuildVersionCache.php --save-gitinfo --wiki={envinfo["wikidbname"]} --conf=/srv/mediawiki-staging/config/LocalSettings.php')
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
                rsync.append(_construct_rsync_command(time=args.ignoretime, location=f'/srv/mediawiki-staging/{folder}/*', dest=f'/srv/mediawiki/{folder}/'))

        if args.extensionlist:  # when adding skins/exts
            rebuild.append(f'sudo -u www-data php /srv/mediawiki/w/extensions/CreateWiki/maintenance/rebuildExtensionListCache.php --wiki={envinfo["wikidbname"]}')

        for cmd in rsync:  # move staged content to live
            exitcodes.append(run_command(cmd))
        non_zero_code(exitcodes)
        if args.l10n:  # setup l10n
            if args.lang:
                for language in str(args.lang).split(','):
                    if not tag_is_valid(language):
                        raise ValueError(f'{language} is not a valid language.')

                lang = f'--lang={args.lang}'
            else:
                lang = ''

            postinstall.append(f'sudo -u www-data php /srv/mediawiki/w/maintenance/mergeMessageFileList.php --quiet --wiki={envinfo["wikidbname"]} --output /srv/mediawiki/config/ExtensionMessageFiles.php')
            rebuild.append(f'sudo -u www-data php /srv/mediawiki/w/maintenance/rebuildLocalisationCache.php {lang} --quiet --wiki={envinfo["wikidbname"]}')

        for cmd in postinstall:  # cmds to run after rsync & install (like mergemessage)
            exitcodes.append(run_command(cmd))
        non_zero_code(exitcodes, nolog=args.nolog)
        for cmd in rebuild:  # update ext list + l10n
            exitcodes.append(run_command(cmd))
        non_zero_code(exitcodes, nolog=args.nolog)

        # see if we are online - exit code 3 if not
        if args.port:
            check_up(Debug=None, Host=envinfo['wikiurl'], verify=False, force=args.force, nolog=args.nolog, port=args.port)
        else:
            check_up(Debug=None, Host=envinfo['wikiurl'], verify=False, force=args.force, nolog=args.nolog)

    # actually set remote lists
    for option in options:
        if options[option]:
            rsyncpaths.append(_get_deployed_path(option))
    if args.files:
        for file in str(args.files).split(','):
            rsyncfiles.append(f'/srv/mediawiki/{file}')
    if args.folders:
        for folder in str(args.folders).split(','):
            rsyncpaths.append(f'/srv/mediawiki/{folder}/')
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
    parser.add_argument('--branch', dest='branch')
    parser.add_argument('--config', dest='config', action='store_true')
    parser.add_argument('--world', dest='world', action='store_true')
    parser.add_argument('--landing', dest='landing', action='store_true')
    parser.add_argument('--errorpages', dest='errorpages', action='store_true')
    parser.add_argument('--l10n', dest='l10n', action='store_true')
    parser.add_argument('--extension-list', dest='extensionlist', action='store_true')
    parser.add_argument('--no-log', dest='nolog', action='store_true')
    parser.add_argument('--force', dest='force', action='store_true')
    parser.add_argument('--files', dest='files')
    parser.add_argument('--folders', dest='folders')
    parser.add_argument('--lang', dest='lang')
    parser.add_argument('--servers', dest='servers', required=True)
    parser.add_argument('--ignore-time', dest='ignoretime', action='store_true')
    parser.add_argument('--port', dest='port')

    run(parser.parse_args(), start)
