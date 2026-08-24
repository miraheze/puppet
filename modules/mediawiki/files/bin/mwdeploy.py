#! /usr/bin/python3

# will eventually be moved to python-functions repository;
# prefer making changes there if possible

import argparse
import contextlib
import json
import os
import re
import socket
import sys
import time
import warnings
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Optional

import requests
import urllib3
from langcodes import tag_is_valid

DEPLOYUSER = 'www-data'
STAGING_ROOT = '/srv/mediawiki-staging'
DEPLOYED_ROOT = '/srv/mediawiki'


def _load_mw_versions() -> dict:
    output = os.popen('/usr/local/bin/getMWVersions').read().strip()
    if not output:
        return {'version': 'version'}
    return json.loads(output)


versions = _load_mw_versions()
repos = {**versions, 'config': 'config', 'errorpages': 'ErrorPages', 'landing': 'landing'}


def _load_patches() -> list:
    loaded = []
    for visibility in ('public', 'private'):
        path = f'{STAGING_ROOT}/patches/{visibility}.json'
        with contextlib.suppress(FileNotFoundError), open(path) as handle:
            loaded += json.load(handle)
    return loaded


patches = _load_patches()

HOSTNAME = socket.gethostname().split('.')[0]


@dataclass(frozen=True)
class Environment:
    wikidbname: str
    wikiurl: str
    servers: list


ENVIRONMENTS = {
    'beta': Environment(
        wikidbname='metawikibeta',
        wikiurl='meta.mirabeta.org',
        servers=['test151'],
    ),
    'prod': Environment(
        wikidbname='testwiki',
        wikiurl='publictestwiki.com',
        servers=[
            'mw151', 'mw152', 'mw153',
            'mw161', 'mw162', 'mw163',
            'mw171', 'mw172', 'mw173',
            'mw181', 'mw182', 'mw183',
            'mw191', 'mw192', 'mw193',
            'mw201', 'mw202', 'mw203',
            'mwtask151', 'mwtask161', 'mwtask171', 'mwtask181',
        ],
    ),
}


def get_environment_info() -> Environment:
    if HOSTNAME.startswith('test'):
        return ENVIRONMENTS['beta']
    return ENVIRONMENTS['prod']


class ComponentPacks:
    """Named bundles of extensions and skins that can be upgraded together."""

    EXTENSIONS = {
        'bundled': ['AbuseFilter', 'CategoryTree', 'Cite', 'CiteThisPage', 'CodeEditor', 'ConfirmEdit', 'DiscussionTools', 'Echo', 'Gadgets', 'ImageMap', 'InputBox', 'Interwiki', 'Linter', 'LoginNotify', 'Math', 'MultimediaViewer', 'Nuke', 'OATHAuth', 'PageImages', 'ParserFunctions', 'PdfHandler', 'Poem', 'ReplaceText', 'Scribunto', 'SpamBlacklist', 'SyntaxHighlight_GeSHi', 'TemplateData', 'TextExtracts', 'Thanks', 'TitleBlacklist', 'VisualEditor', 'WikiEditor'],
        'mleb': ['Babel', 'cldr', 'CleanChanges', 'Translate', 'UniversalLanguageSelector'],
        'socialtools': ['AJAXPoll', 'BlogPage', 'Comments', 'ContributionScores', 'HAWelcome', 'ImageRating', 'MediaWikiChat', 'NewSignupPage', 'PollNY', 'QuizGame', 'RandomGameUnit', 'SocialProfile', 'Video', 'VoteNY', 'WikiForum', 'WikiTextLoggedInOut'],
        'universalomega': ['AutoCreatePage', 'DynamicPageList4', 'PortableInfobox', 'Preloader', 'SimpleTooltip'],
        'wikitide': ['CreateWiki', 'DataDump', 'DiscordNotifications', 'GlobalNewFiles', 'ImportDump', 'IncidentReporting', 'ManageWiki', 'MatomoAnalytics', 'MirahezeMagic', 'PDFEmbed', 'RemovePII', 'RequestCustomDomain', 'RottenLinks', 'WikiDiscover'],
    }
    SKINS = {
        'bundled': ['MinervaNeue', 'MonoBook', 'Timeless', 'Vector'],
        'universalomega': ['Cosmos', 'Monaco'],
    }

    @classmethod
    def extensions(cls, pack_name: str) -> list[str]:
        return cls.EXTENSIONS.get(pack_name, [])

    @classmethod
    def skins(cls, pack_name: str) -> list[str]:
        return cls.SKINS.get(pack_name, [])


def get_extensions_in_pack(pack_name: str) -> list[str]:
    return ComponentPacks.extensions(pack_name)


def get_skins_in_pack(pack_name: str) -> list[str]:
    return ComponentPacks.skins(pack_name)


class ComponentDiscovery:
    """Finds the extensions and skins that actually exist on disk for a set of versions."""

    @staticmethod
    def _scan(kind: str, mw_versions: list[str]) -> list[str]:
        found = []
        for version in mw_versions:
            path = f'{STAGING_ROOT}/{version}/{kind}/'
            with os.scandir(path) as entries:
                found += [entry.name for entry in entries if entry.is_dir()]
        return sorted(found)

    @classmethod
    def extensions(cls, mw_versions: list[str]) -> list[str]:
        return cls._scan('extensions', mw_versions)

    @classmethod
    def skins(cls, mw_versions: list[str]) -> list[str]:
        return cls._scan('skins', mw_versions)


def get_valid_extensions(mw_versions: list[str]) -> list[str]:
    return ComponentDiscovery.extensions(mw_versions)


def get_valid_skins(mw_versions: list[str]) -> list[str]:
    return ComponentDiscovery.skins(mw_versions)


_BUILD_PATTERN = r'^.*?(\.github/.*?|\.phan/.*?|tests/.*?|composer(\.json|\.lock)|package(-lock)?\.json|yarn\.lock|(\.phpcs|\.stylelintrc|\.eslintrc|\.prettierrc|\.stylelintignore|\.eslintignore|\.prettierignore|tsconfig)\.json|\.nvmrc|\.svgo\.config\.js|Gruntfile\.js|bundlesize\.config\.json|jsdoc\.json)$'
BUILD_REGEX = re.compile(_BUILD_PATTERN)
CODECHANGE_REGEX = re.compile(rf'(?!.*{_BUILD_PATTERN})^.*?(\.(php|js|css|less|scss|vue|lua|mustache|d\.ts)|extension(-repo|-client)?\.json|skin\.json)$')
SCHEMA_REGEX = re.compile(rf'(?!.*{_BUILD_PATTERN})^.*?\.sql$')
I18N_REGEX = re.compile(r'^.*?i18n/.*?\.json$')

CHANGE_TAG_MAP = {
    CODECHANGE_REGEX: 'code change',
    SCHEMA_REGEX: 'schema change',
    BUILD_REGEX: 'build',
    I18N_REGEX: 'i18n',
}


class ChangeTagger:
    """Classifies the files a git pull just changed, so a deploy can flag risky changes."""

    TAG_MAP = CHANGE_TAG_MAP

    @staticmethod
    def changed_files(path: str, version: str) -> list[str]:
        repo_dir = os.path.join(STAGING_ROOT, version, path)
        raw = os.popen(f'git -C {repo_dir} --no-pager --git-dir={repo_dir}/.git diff --name-only HEAD@{{1}} HEAD 2> /dev/null').readlines()
        return [line.strip() for line in raw]

    @classmethod
    def files_of_type(cls, path: str, version: str, change_type: str) -> set:
        files = set()
        for file in cls.changed_files(path, version):
            for regex, tag in cls.TAG_MAP.items():
                if tag == change_type and regex.match(file):
                    files.add(file)
        return files

    @classmethod
    def tags(cls, path: str, version: str) -> set:
        found = set()
        for file in cls.changed_files(path, version):
            for regex, tag in cls.TAG_MAP.items():
                if regex.match(file):
                    found.add(tag)
        return found


def get_change_tag_map() -> dict:
    return ChangeTagger.TAG_MAP


def get_changed_files(path: str, version: str) -> list[str]:
    return ChangeTagger.changed_files(path, version)


def get_changed_files_type(path: str, version: str, change_type: str) -> set:
    return ChangeTagger.files_of_type(path, version, change_type)


def get_change_tags(path: str, version: str) -> set:
    return ChangeTagger.tags(path, version)


class ShellExecutor:
    """Runs shell commands and, where the caller allows it, runs several at once."""

    @staticmethod
    def run(cmd: str) -> int:
        start = time.time()
        print(f'Execute: {cmd}')
        ec = os.system(cmd)
        print(f'Completed ({ec}) in {str(int(time.time() - start))}s!')
        return ec

    @staticmethod
    def run_parallel(cmds: list[str], max_workers: int = 8) -> list[int]:
        """Runs independent commands concurrently. Results come back in the same order as cmds."""
        if not cmds:
            return []
        with ThreadPoolExecutor(max_workers=min(max_workers, len(cmds))) as pool:
            return list(pool.map(ShellExecutor.run, cmds))

    @staticmethod
    def ensure_all_zero(codes: list[int], nolog: bool = True, leave: bool = True) -> bool:
        for code in codes:
            if code != 0:
                if not nolog:
                    os.system('/usr/local/bin/logsalmsg DEPLOY ABORTED: Non-Zero Exit Code in prep, see output.')
                if leave:
                    print('Exiting due to non-zero status.')
                    sys.exit(1)
                return True
        return False


def run_command(cmd: str) -> int:
    return ShellExecutor.run(cmd)


def non_zero_code(ec: list[int], nolog: bool = True, leave: bool = True) -> bool:
    return ShellExecutor.ensure_all_zero(ec, nolog=nolog, leave=leave)


class CanaryChecker:
    """Confirms a wiki responds correctly after a deploy step.

    Reuses a single requests.Session so repeated checks (there can be dozens
    in a full fleet deploy) don't pay for a fresh TLS handshake every time.
    """

    def __init__(self):
        self._session = requests.Session()

    def _request(self, proto: str, domain: str, port: int, headers: dict, verify: bool, use_cert: bool) -> requests.Response:
        url = f'{proto}{domain}:{port}/w/api.php?action=query&meta=siteinfo&formatversion=2&format=json'
        kwargs = {'headers': headers, 'verify': verify}
        if use_cert:
            kwargs['cert'] = (
                '/etc/ssl/localcerts/mwdeploy.crt',
                f'{STAGING_ROOT}/mwdeploy-client-cert.key',
            )
        return self._session.get(url, **kwargs)

    def check(self, nolog: bool, Debug: Optional[str] = None, Host: Optional[str] = None,
              domain: str = 'meta.miraheze.org', verify: bool = True, force: bool = False,
              port: int = 443, use_cert: bool = True) -> bool:
        if verify is False:
            os.environ['PYTHONWARNINGS'] = 'ignore:Unverified HTTPS request'
        if not Debug and not Host:
            raise Exception('Host or Debug must be specified')

        headers = {'User-Agent': 'wikitide/mwdeploy.py'}
        if Debug:
            warnings.filterwarnings('default', category=urllib3.exceptions.InsecureRequestWarning)
            headers['X-WikiTide-Debug'] = Debug
            location = f'{domain}@{Debug}'
            debug_access_key = os.getenv('DEBUG_ACCESS_KEY')
            if debug_access_key:
                headers['X-WikiTide-Debug-Access-Key'] = debug_access_key
        else:
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
            os.environ['NO_PROXY'] = 'localhost'
            domain = 'localhost'
            headers['host'] = f'{Host}'
            location = f'{Host}@{domain}'

        if force:
            print(f'Skipping canary check on {location} due to --force')
            return True

        proto = 'https://' if port == 443 else 'http://'
        req = self._request(proto, domain, port, headers, verify, use_cert)

        up = (
            req.status_code == 200
            and 'mainpageisdomainroot' in req.text
            and (Debug is None or Debug in req.headers['X-Served-By'])
        )
        if not up:
            print(f'Status: {req.status_code}')
            print(f'Text: {"miraheze" in req.text} \n {req.text}')
            if 'X-Served-By' not in req.headers:
                req.headers['X-Served-By'] = 'None'
            print(f'Debug: {(Debug is None or Debug in req.headers["X-Served-By"])}')
            print(f'Canary check failed for {location}. Aborting... - use --force to proceed')
            message = f'/usr/local/bin/logsalmsg DEPLOY ABORTED: Canary check failed for {location}'
            if nolog:
                print(message)
            else:
                os.system(message)
            sys.exit(3)
        return up


_default_canary_checker = CanaryChecker()


def check_up(nolog: bool, Debug: Optional[str] = None, Host: Optional[str] = None,
             domain: str = 'meta.miraheze.org', verify: bool = True, force: bool = False,
             port: int = 443, use_cert: bool = True) -> bool:
    return _default_canary_checker.check(nolog, Debug=Debug, Host=Host, domain=domain, verify=verify, force=force, port=port, use_cert=use_cert)


class PathResolver:
    """Resolves the staging and deployed filesystem paths for a repo."""

    def __init__(self, repo_map: dict):
        self._repos = repo_map

    def staging(self, repo: str, version: str = '') -> str:
        if version and ('extensions/' in repo or 'skins/' in repo or repo == 'vendor'):
            return f'{STAGING_ROOT}/{version}/{repo}'
        return f'{STAGING_ROOT}/{self._repos[repo]}/'

    def deployed(self, repo: str, version: str = '') -> str:
        if version and ('extensions/' in repo or 'skins/' in repo or repo == 'vendor'):
            return f'{DEPLOYED_ROOT}/{version}/{repo}'
        return f'{DEPLOYED_ROOT}/{self._repos[repo]}/'


_paths = PathResolver(repos)


def _get_staging_path(repo: str, version: str = '') -> str:
    return _paths.staging(repo, version)


def _get_deployed_path(repo: str, version: str = '') -> str:
    return _paths.deployed(repo, version)


class RsyncCommandBuilder:
    """Builds the rsync command lines used for both local staging and remote fleet syncs."""

    def __init__(self, deploy_user: str = DEPLOYUSER):
        self._deploy_user = deploy_user

    def build(self, time, dest: str, recursive: bool = True, local: bool = True,
              location: Optional[str] = None, server: Optional[str] = None) -> str:
        params = '--inplace' if time else '--update'
        if recursive:
            params += ' -r --delete'

        if local:
            if location is None:
                raise Exception('Location must be specified for local rsync.')
            return f'sudo -u {self._deploy_user} rsync {params} --exclude=".*" {location} {dest}'

        if location is None:
            location = dest
        if location == dest and server:
            fqdn = socket.getfqdn()
            domain = '.'.join(fqdn.split('.')[1:])
            return f'sudo -u {self._deploy_user} rsync {params} -e "ssh -i {STAGING_ROOT}/deploykey" {dest} {self._deploy_user}@{server}.{domain}:{dest}'

        # a return None here would be dangerous - except and ignore R503 as return after Exception is not reachable
        raise Exception(f'Error constructing command. Either server was missing or {location} != {dest}')


_rsync_builder = RsyncCommandBuilder()


def _construct_rsync_command(time, dest: str, recursive: bool = True, local: bool = True,
                             location: Optional[str] = None, server: Optional[str] = None) -> str:
    return _rsync_builder.build(time, dest, recursive=recursive, local=local, location=location, server=server)


class GitCommandBuilder:
    """Builds the git command lines used to pull, reset, and patch a staged repo."""

    def __init__(self, paths: PathResolver, deploy_user: str = DEPLOYUSER):
        self._paths = paths
        self._deploy_user = deploy_user

    def pull(self, repo: str, submodules: bool = False, branch: Optional[str] = None,
             quiet: bool = True, version: str = '') -> str:
        extra = ' '
        if submodules:
            extra += '--recurse-submodules '
        if branch:
            extra += f'origin {branch} '
        extra += '--quiet' if quiet else '2> /dev/null'
        return f'sudo -u {self._deploy_user} git -C {self._paths.staging(repo, version)} pull{extra}'

    def reset_revert(self, repo: str, version: str = '') -> str:
        return f'sudo -u {self._deploy_user} git -C {self._paths.staging(repo, version)} reset --hard HEAD@{{1}}'

    def reset_hard(self, repo: str, version: str = '') -> str:
        return f'sudo -u {self._deploy_user} git -C {self._paths.staging(repo, version)} reset --hard'

    def apply(self, repo: str, patchfile: str, version: str = '', check: bool = False) -> str:
        option = ' --check' if check else ' --index'
        return f'sudo -u {self._deploy_user} git -C {self._paths.staging(repo, version)} apply{option} {patchfile}'

    def is_repo(self, repo: str, version: str) -> bool:
        return os.path.isdir(os.path.join(self._paths.staging(repo, version), '.git'))


_git = GitCommandBuilder(_paths)


def _construct_git_pull(repo: str, submodules: bool = False, branch: Optional[str] = None,
                        quiet: bool = True, version: str = '') -> str:
    return _git.pull(repo, submodules=submodules, branch=branch, quiet=quiet, version=version)


def _construct_git_reset_revert(repo: str, version: str = '') -> str:
    return _git.reset_revert(repo, version)


def _construct_git_reset_hard(repo: str, version: str = '') -> str:
    return _git.reset_hard(repo, version)


def _construct_git_apply(repo: str, patchfile: str, version: str = '', check: bool = False) -> str:
    return _git.apply(repo, patchfile, version, check)


def _is_git_repo(repo: str, version: str) -> bool:
    return _git.is_repo(repo, version)


class WorldReset:
    """Commands used by --reset-world to wipe and rebuild a version's staging tree."""

    def __init__(self, paths: PathResolver, deploy_user: str = DEPLOYUSER):
        self._paths = paths
        self._deploy_user = deploy_user

    def remove_staging(self, version: str) -> str:
        return f'sudo -u {self._deploy_user} rm -rf {self._paths.staging(version)}'

    @staticmethod
    def run_puppet() -> str:
        return 'sudo puppet agent -tv'


_world_reset = WorldReset(_paths)


def _construct_reset_mediawiki_rm_staging(version: str) -> str:
    return _world_reset.remove_staging(version)


def _construct_reset_mediawiki_run_puppet() -> str:
    return _world_reset.run_puppet()


class PatchApplier:
    """Matches and applies the public and private patch sets to a repo."""

    def __init__(self, patch_list: list, paths: PathResolver, git: GitCommandBuilder, deploy_user: str = DEPLOYUSER):
        self._patches = patch_list
        self._paths = paths
        self._git = git
        self._deploy_user = deploy_user

    def _matches(self, patch: dict, repo: str, version: str) -> bool:
        path = patch['path']
        if path == repo and path in versions:
            return True  # mw core patches
        staging_path = self._paths.staging(repo, version)
        if not staging_path.endswith(path):
            return False

        patch_versions = patch['versions']
        if 'all' in patch_versions:
            return True

        return version in patch_versions and staging_path.endswith(f'{version}/{path}')

    def _apply_git(self, repo: str, patchfile: str, version: str) -> int:
        check = run_command(self._git.apply(repo, patchfile, version, check=True))
        if check == 0:
            return run_command(self._git.apply(repo, patchfile, version))
        return check

    def _apply_plain(self, repo: str, patchfile: str, version: str) -> int:
        # For non-git repos (like those installed via composer)
        return run_command(f'sudo -u {self._deploy_user} patch -p1 -N -d {self._paths.staging(repo, version)} -i {patchfile} -r -')

    def apply_all(self, repo: str, version: str = '') -> list[int]:
        exitcodes = []
        is_git = self._git.is_repo(repo, version)
        to_apply = [patch for patch in self._patches if self._matches(patch, repo, version)]

        for patch in to_apply:
            visibility = 'public' if patch['public'] else 'private'
            patchfile = f"{STAGING_ROOT}/patches/{visibility}/{patch['file']}"

            if not os.path.isfile(patchfile):
                print(f'WARNING: Patch file {patchfile} could not be found!')
                continue

            code = self._apply_git(repo, patchfile, version) if is_git else self._apply_plain(repo, patchfile, version)

            if code == 0:
                exitcodes.append(code)
                continue

            print(f"ERROR: Could not apply patch {patch['file']}")
            if patch['failureStrategy'] == 'abort':
                print('Aborting!')
                sys.exit(1)
            print('Skipping patch...')

        return exitcodes


_patch_applier = PatchApplier(patches, _paths, _git)


def _patch_matches(patch: dict, repo: str, version: str) -> bool:
    return _patch_applier._matches(patch, repo, version)


def _apply_patches(repo: str, version: str = '') -> list[int]:
    return _patch_applier.apply_all(repo, version)


def _apply_patch_git(repo: str, patchfile: str, version: str) -> int:
    return _patch_applier._apply_git(repo, patchfile, version)


def _apply_patch_plain(repo: str, patchfile: str, version: str) -> int:
    return _patch_applier._apply_plain(repo, patchfile, version)


class RemoteDeployer:
    """Pushes a staged path or file out to a server fleet.

    Servers are synced in parallel instead of one at a time, since a full
    prod deploy can touch over twenty machines and there's no reason to make
    server five wait on server four finishing.
    """

    def __init__(self, rsync_builder: RsyncCommandBuilder, canary, hostname: str = HOSTNAME, max_workers: int = 8):
        self._rsync_builder = rsync_builder
        self._canary = canary
        self._hostname = hostname
        self._max_workers = max_workers

    def _deploy_to_server(self, server: str, time_flag, path: str, recursive: bool, envinfo: Environment, nolog: bool, force: bool) -> int:
        print(f'Deploying {path} to {server}.')
        cmd = self._rsync_builder.build(time=time_flag, local=False, dest=path, server=server, recursive=recursive)
        ec = ShellExecutor.run(cmd)
        self._canary.check(nolog, Debug=server, force=force, domain=envinfo.wikiurl)
        print(f'Deployed {path} to {server}.')
        return ec  # noqa: R504

    def sync(self, time_flag, serverlist: list[str], path: str, envinfo: Environment, nolog: bool,
             recursive: bool = True, force: bool = False) -> int:
        print(f'Start {path} deploys.')
        targets = [server for server in serverlist if self._hostname != server.split('.')[0]]

        codes = []
        if targets:
            with ThreadPoolExecutor(max_workers=min(self._max_workers, len(targets))) as pool:
                futures = [
                    pool.submit(self._deploy_to_server, server, time_flag, path, recursive, envinfo, nolog, force)
                    for server in targets
                ]
                codes = [future.result() for future in as_completed(futures)]

        print(f'Finished {path} deploys.')
        if not codes:
            return 0
        return next((code for code in codes if code != 0), codes[-1])


_remote_deployer = RemoteDeployer(_rsync_builder, _default_canary_checker)


def remote_sync_file(time: str, serverlist: list[str], path: str, envinfo: Environment, nolog: bool,
                     recursive: bool = True, force: bool = False) -> int:
    return _remote_deployer.sync(time, serverlist, path, envinfo, nolog, recursive=recursive, force=force)


class DeploymentRunner:
    """Coordinates one mwdeploy invocation: local staging, then a fleet-wide rollout."""

    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.envinfo = get_environment_info()


    def run(self, start: float) -> None:  # pragma: no cover
        args = self.args
        loginfo = self._build_loginfo()

        if args.upgrade_world and not args.reset_world:
            args.world = True
            args.pull = 'world'
            args.l10n = True
            args.ignore_time = True
            args.extension_list = True
            args.upgrade_vendor = True
            args.upgrade_extensions = get_valid_extensions(args.versions)
            args.upgrade_skins = get_valid_skins(args.versions)

        if len(args.servers) > 1 and args.servers == self.envinfo.servers:
            loginfo['servers'] = 'all'

        use_version = bool(
            args.world or args.l10n or args.extension_list or args.reset_world
            or args.upgrade_extensions or args.upgrade_skins or args.upgrade_vendor or args.apply_patches,
        )

        if args.versions:
            if args.upgrade_extensions == get_valid_extensions(args.versions):
                loginfo['upgrade_extensions'] = 'all'
            if args.upgrade_skins == get_valid_skins(args.versions):
                loginfo['upgrade_skins'] = 'all'
            if args.upgrade_pack:
                del loginfo['upgrade_extensions']
                del loginfo['upgrade_skins']
            if not use_version:
                del loginfo['versions']

        synced = loginfo['servers']
        del loginfo['servers']

        self._log(f'starting deploy of "{loginfo}" to {synced}', args.nolog)

        exitcodes = self.process()
        failed = non_zero_code(exitcodes, leave=False)

        fintext = f'finished deploy of "{loginfo}" to {synced}'
        if failed:
            self._log(f'{fintext} - FAIL: {exitcodes}', args.nolog)
            sys.exit(1)

        if use_version:
            for version in args.versions:
                exitcodes = self.process(version)
                failed = non_zero_code(exitcodes, leave=False)
                if failed:
                    self._log(f'{fintext} - FAIL: {exitcodes}', args.nolog)
                    sys.exit(1)

        fintext += f' - SUCCESS in {int(time.time() - start)}s'
        self._log(fintext, args.nolog)

    def process(self, version: str = '') -> list[int]:  # pragma: no cover
        self._reset_state()
        args = self.args
        envinfo = self.envinfo
        options = {
            'config': args.config and not version,
            'world': (args.world or args.reset_world) and version,
            'landing': args.landing and not version,
            'errorpages': args.errorpages and not version,
        }

        if HOSTNAME in args.servers:
            self._runner = f'/srv/mediawiki/{version}/maintenance/run.php ' if version else ''
            self._runner_staging = f'{STAGING_ROOT}/{version}/maintenance/run.php ' if version else ''

            if version and args.reset_world:
                self.stage.append(_world_reset.remove_staging(version))
                self.stage.append(_world_reset.run_puppet())

            self._pull_named_repos(version)

            if version:
                self._upgrade_vendor(version)
                for kind, items in (('extensions', args.upgrade_extensions), ('skins', args.upgrade_skins)):
                    if items:
                        self._upgrade_components(kind, items, version)

            for cmd in self.stage:  # setup env, git pull etc
                if 'composer' in cmd:
                    os.chdir(_paths.staging(version))
                self.exitcodes.append(run_command(cmd))
            non_zero_code(self.exitcodes, nolog=args.nolog)

            for option in options:  # configure rsync & custom data for repos
                if not options[option]:
                    continue
                if option == 'world':  # install steps for world
                    option = version
                    os.chdir(_paths.staging(version))
                    self.exitcodes.append(run_command(
                        f'sudo -u {DEPLOYUSER} http_proxy=http://bastion.fsslc.wtnet:8080 '
                        f'https_proxy=http://bastion.fsslc.wtnet:8080 composer update --no-dev --quiet',
                    ))
                    self._needs_version_cache_rebuild = True
                self.rsync.append(_rsync_builder.build(time=args.ignore_time, location=f'{_paths.staging(option)}*', dest=_paths.deployed(option)))
            non_zero_code(self.exitcodes, nolog=args.nolog)

            # a version upgrade only needs one RebuildVersionCache run at the end,
            # no matter how many extensions, skins, or core itself were upgraded
            if version and self._needs_version_cache_rebuild:
                self.rebuild.append(
                    f'sudo -u {DEPLOYUSER} MW_INSTALL_PATH={STAGING_ROOT}/{version} php {self._runner_staging}'
                    f'MirahezeMagic:RebuildVersionCache --save-gitinfo --version={version} '
                    f'--wiki={envinfo.wikidbname} --conf={STAGING_ROOT}/config/LocalSettings.php',
                )
                self.rsyncpaths.append(f'{DEPLOYED_ROOT}/cache/{version}/gitinfo/')

            if version and args.reset_world:  # complete reset_world by applying patches, after potential composer update
                applied = []
                for patch in patches:
                    if patch['path'] not in applied:
                        self.exitcodes.extend(_patch_applier.apply_all(patch['path'], version))
                        applied.append(patch['path'])
            non_zero_code(self.exitcodes, nolog=args.nolog)

            if version and args.apply_patches:
                for repo in args.apply_patches:
                    self.exitcodes.extend(_patch_applier.apply_all(repo, version))
                    staging_path = _paths.staging(repo, version)  # non-consistent behavior, ensure terminating /
                    staging_path = staging_path if staging_path.endswith('/') else staging_path + '/'
                    dest_path = _paths.deployed(repo, version)
                    dest_path = dest_path if dest_path.endswith('/') else dest_path + '/'
                    self.rsync.append(_rsync_builder.build(time=args.ignore_time, location=f'{staging_path}*', dest=dest_path))
                    self.rsyncpaths.append(dest_path)
            non_zero_code(self.exitcodes, nolog=args.nolog)

            if args.files and not version:  # specfic extra files
                for file in str(args.files).split(','):
                    self.rsync.append(_rsync_builder.build(time=args.ignore_time, recursive=False, location=f'{STAGING_ROOT}/{file}', dest=f'{DEPLOYED_ROOT}/{file}'))
            if args.folders and not version:  # specfic extra folders
                for folder in str(args.folders).split(','):
                    self.rsync.append(_rsync_builder.build(time=args.ignore_time, location=f'{STAGING_ROOT}/{folder}/*', dest=f'{DEPLOYED_ROOT}/{folder}/'))

            if args.extension_list and version:  # when adding skins/exts
                self.rebuild.append(f'sudo -u {DEPLOYUSER} php {self._runner}ManageWiki:RebuildExtensionListCache --wiki={envinfo.wikidbname} --cachedir={DEPLOYED_ROOT}/cache/{version}')

            for cmd in self.rsync:  # move staged content to live
                self.exitcodes.append(run_command(cmd))
            non_zero_code(self.exitcodes)

            if args.l10n and version:  # setup l10n
                lang = f'--lang={args.lang}' if args.lang else ''
                self.postinstall.append(f'sudo -u {DEPLOYUSER} php {self._runner}MirahezeMagic:MergeMessageFileList --quiet --wiki={envinfo.wikidbname} --extensions-dir={DEPLOYED_ROOT}/{version}/extensions:{DEPLOYED_ROOT}/{version}/skins --output {DEPLOYED_ROOT}/config/ExtensionMessageFiles-{version}.php')
                self.rebuild.append(f'sudo -u {DEPLOYUSER} php {self._runner}{DEPLOYED_ROOT}/{version}/maintenance/rebuildLocalisationCache.php {lang} --quiet --wiki={envinfo.wikidbname}')

            for cmd in self.postinstall:  # cmds to run after rsync & install (like mergemessage)
                self.exitcodes.append(run_command(cmd))
            non_zero_code(self.exitcodes, nolog=args.nolog)
            for cmd in self.rebuild:  # update ext list + l10n
                self.exitcodes.append(run_command(cmd))
            non_zero_code(self.exitcodes, nolog=args.nolog)

            # see if we are online - exit code 3 if not
            if args.port:
                check_up(Debug=None, Host=envinfo.wikiurl, verify=False, force=args.force, nolog=args.nolog, port=args.port)
            else:
                check_up(Debug=None, Host=envinfo.wikiurl, verify=False, force=args.force, nolog=args.nolog)

        # actually set remote lists
        for option in options:
            if options[option]:
                target = version if option == 'world' else option
                self.rsyncpaths.append(_paths.deployed(target))
        if args.files and not version:
            for file in str(args.files).split(','):
                self.rsyncfiles.append(f'{DEPLOYED_ROOT}/{file}')
        if args.folders and not version:
            for folder in str(args.folders).split(','):
                self.rsyncpaths.append(f'{DEPLOYED_ROOT}/{folder}/')
        if args.extension_list and version:
            self.rsyncfiles.append(f'{DEPLOYED_ROOT}/cache/{version}/extension-list.php')
        if args.l10n and version:
            self.rsyncpaths.append(f'{DEPLOYED_ROOT}/cache/{version}/l10n/')

        for path in self.rsyncpaths:
            self.exitcodes.append(_remote_deployer.sync(args.ignore_time, args.servers, path, envinfo, args.nolog, force=args.force))
        for file in self.rsyncfiles:
            self.exitcodes.append(_remote_deployer.sync(args.ignore_time, args.servers, file, envinfo, args.nolog, recursive=False, force=args.force))

        self._print_summary()
        return self.exitcodes


    def _reset_state(self) -> None:
        self.exitcodes = []
        self.rsyncpaths = []
        self.rsyncfiles = []
        self.rsync = []
        self.rebuild = []
        self.postinstall = []
        self.stage = []
        self.newschema = []
        self.tagsinfo = []
        self.warnings = {}
        self._needs_version_cache_rebuild = False
        self._runner = ''
        self._runner_staging = ''

    def _build_loginfo(self) -> dict:
        loginfo = {}
        for name, value in vars(self.args).items():
            if value is None or value is False:
                continue
            if isinstance(value, list) and len(value) == 1:
                loginfo[name] = value[0]
            else:
                loginfo[name] = value
        return loginfo

    @staticmethod
    def _log(text: str, nolog: bool) -> None:
        if nolog:
            print(text)
        else:
            os.system(f'/usr/local/bin/logsalmsg {text}')

    def _print_summary(self) -> None:
        if self.tagsinfo:
            print('TAGS:')
            for info in self.tagsinfo:
                print(info)
        if self.newschema:
            print('WARNING: NEW SCHEMA CHANGES DETECTED:')
            for schema in self.newschema:
                print(schema)

    def _pull_named_repos(self, version: str) -> None:
        if not self.args.pull:
            return
        for repo in str(self.args.pull).split(','):
            try:
                if repo == 'world':
                    if not version:
                        continue
                    repo = version
                self.exitcodes.append(run_command(_git.pull(repo, branch=self.args.branch)))
                self.exitcodes.extend(_patch_applier.apply_all(repo))
            except KeyError:
                print(f'Failed to pull {repo} due to invalid name')

    def _upgrade_vendor(self, version: str) -> None:
        if not self.args.upgrade_vendor:
            return
        self.exitcodes.append(run_command(_git.reset_hard('vendor', version=version)))
        self.exitcodes.append(run_command(_git.pull('vendor', submodules=True, version=version)))
        self.exitcodes.extend(_patch_applier.apply_all('vendor', version))
        if not self.args.world:
            self.stage.append(
                f'sudo -u {DEPLOYUSER} http_proxy=http://bastion.fsslc.wtnet:8080 '
                f'https_proxy=http://bastion.fsslc.wtnet:8080 composer update --no-dev --quiet',
            )
            self.rsync.append(_rsync_builder.build(time=self.args.ignore_time, location=f'{STAGING_ROOT}/{version}/vendor/*', dest=f'{DEPLOYED_ROOT}/{version}/vendor/'))
            self.rsyncpaths.append(f'{DEPLOYED_ROOT}/{version}/vendor/')

    def _upgrade_components(self, kind: str, items: list[str], version: str) -> None:
        # non-git repos (or ones missing entirely) are handled right away, since
        # there's nothing to fetch. everything else is queued up and fetched in
        # parallel, since a --upgrade-world run can mean pulling dozens of repos
        # and there's no reason to do that one network round trip at a time.
        to_fetch = []
        for name in items:
            repo = f'{kind}/{name}'
            if not _git.is_repo(repo, version):
                print(f'Upgrading {name}')
                self.exitcodes.extend(_patch_applier.apply_all(repo, version))
                if not self.args.world:
                    self.rsync.append(_rsync_builder.build(time=self.args.ignore_time, location=f'{STAGING_ROOT}/{version}/{repo}/*', dest=f'{DEPLOYED_ROOT}/{version}/{repo}/'))
                    self.rsyncpaths.append(f'{DEPLOYED_ROOT}/{version}/{repo}/')
                continue

            if not os.path.exists(_paths.staging(repo, version)):
                print(f'{name} does not exist for {version}. Skipping...')
                continue

            to_fetch.append(name)

        if not to_fetch:
            return

        with ThreadPoolExecutor(max_workers=min(8, len(to_fetch))) as pool:
            fetched = list(pool.map(lambda name: self._fetch_component(kind, name, version), to_fetch))

        # confirmation prompts, patch application, and rsync queueing all touch
        # shared state, so they're replayed sequentially once every fetch is done
        for name, repo, output, status in fetched:
            self._process_component_fetch(name, repo, output, status, version)

    @staticmethod
    def _fetch_component(kind: str, name: str, version: str):
        repo = f'{kind}/{name}'
        process = os.popen(_git.pull(repo, submodules=True, quiet=False, version=version))
        output = process.read().strip()
        status = process.close()
        return name, repo, output, status

    def _process_component_fetch(self, name: str, repo: str, output: str, status, version: str) -> None:
        args = self.args
        exitcode = 0
        if status and not args.force:
            exitcode = os.waitstatus_to_exitcode(status)
            self.exitcodes.append(exitcode)

        if exitcode == 0 and (args.force_upgrade or output != 'Already up to date.'):
            print(f'Upgrading {name}')
            self.exitcodes.extend(_patch_applier.apply_all(repo, version))
            for file in ChangeTagger.files_of_type(repo, version, 'schema change'):
                if not args.skip_schema_confirm and name not in self.warnings:
                    self.warnings[name] = True
                    print('WARNING: upgrade contains schema changes.')
                    try:
                        if input('Type Y to confirm: ').upper() != 'Y':
                            self.exitcodes.append(run_command(_git.reset_revert(repo, version)))
                            print('reverted')
                            continue
                        self.newschema.append(f'{STAGING_ROOT}/{version}/{repo}/{file}')
                    except KeyboardInterrupt:
                        run_command(_git.reset_revert(repo, version))
                        print('reverted')
                        self._print_summary()
                        print('Operation aborted by user')
                        sys.exit(1)

            if args.show_tags:
                tags = ChangeTagger.tags(repo, version)
                if tags:
                    self.tagsinfo.append(f'Tags for {name}: {", ".join(sorted(tags))}')

            if not args.world:
                self.rsync.append(_rsync_builder.build(time=args.ignore_time, location=f'{STAGING_ROOT}/{version}/{repo}/*', dest=f'{DEPLOYED_ROOT}/{version}/{repo}/'))
                self.rsyncpaths.append(f'{DEPLOYED_ROOT}/{version}/{repo}/')
                self._needs_version_cache_rebuild = True
        elif exitcode == 0:
            print(f'{name} already up to date. Skipping...')
        else:
            print(f'Failed to upgrade {name} (exit code: {exitcode}).')


def run(args: argparse.Namespace, start: float) -> None:  # pragma: no cover
    DeploymentRunner(args).run(start)


def run_process(args: argparse.Namespace, version: str = '') -> list[int]:  # pragma: no cover
    return DeploymentRunner(args).process(version)


class UpgradeExtensionsAction(argparse.Action):  # pragma: no cover
    def __call__(self, parser, namespace, values, option_string=None):  # noqa: U100
        mw_versions = getattr(namespace, 'versions', None)
        if not mw_versions:
            parser.error('--versions is required when using --upgrade-extensions (--versions must come before --upgrade-extensions)')
        input_extensions = values.split(',')
        valid_extensions = get_valid_extensions(mw_versions)
        if 'all' in input_extensions:
            input_extensions = valid_extensions
        invalid_extensions = set(input_extensions) - set(valid_extensions)
        if invalid_extensions:
            parser.error(f'invalid extension choice(s): {", ".join(invalid_extensions)}')
        setattr(namespace, self.dest, sorted(input_extensions))


class UpgradeSkinsAction(argparse.Action):  # pragma: no cover
    def __call__(self, parser, namespace, values, option_string=None):  # noqa: U100
        mw_versions = getattr(namespace, 'versions', None)
        if not mw_versions:
            parser.error('--versions is required when using --upgrade-skins (--versions must come before --upgrade-skins)')
        input_skins = values.split(',')
        valid_skins = get_valid_skins(mw_versions)
        if 'all' in input_skins:
            input_skins = valid_skins
        invalid_skins = set(input_skins) - set(valid_skins)
        if invalid_skins:
            parser.error(f'invalid skin choice(s): {", ".join(invalid_skins)}')
        setattr(namespace, self.dest, sorted(input_skins))


class UpgradePackAction(argparse.Action):
    def __call__(self, parser, namespace, value, option_string=None):  # noqa: U100
        setattr(namespace, 'upgrade_extensions', sorted(ComponentPacks.extensions(value)))
        setattr(namespace, 'upgrade_skins', sorted(ComponentPacks.skins(value)))
        setattr(namespace, 'upgrade_pack', value)


class LangAction(argparse.Action):
    def __call__(self, parser, namespace, value, option_string=None):  # noqa: U100
        if not getattr(namespace, 'l10n', False):
            parser.error('--lang can not be used without --l10n (--l10n must come before --lang)')
        invalid_langs = [language for language in value.split(',') if not tag_is_valid(language)]
        if invalid_langs:
            parser.error(f'invalid language choice(s): {", ".join(invalid_langs)}')
        setattr(namespace, 'lang', value)


class VersionsAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):  # noqa: U100
        input_versions = values.split(',')
        valid_versions = [version for version in versions.values() if os.path.exists(f'{STAGING_ROOT}/{version}')]
        if 'all' in input_versions:
            input_versions = valid_versions
        invalid_versions = set(input_versions) - set(valid_versions)
        if invalid_versions:
            parser.error(f'invalid version choice(s): {", ".join(invalid_versions)}')
        setattr(namespace, self.dest, input_versions)


class ServersAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):  # noqa: U100
        input_servers = values.split(',')
        valid_servers = get_environment_info().servers
        if 'all' in input_servers:
            input_servers = valid_servers
        invalid_servers = set(input_servers) - set(valid_servers)
        if invalid_servers:
            parser.error(f'invalid server choice(s): {", ".join(invalid_servers)}')
        setattr(namespace, self.dest, input_servers)


class ApplyPatchesAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):  # noqa: U100
        input_repos = values.split(',')
        if not getattr(namespace, 'versions', None):
            parser.error('--versions is required when using --apply-patches (--versions must come before --apply-patches)')
        setattr(namespace, self.dest, input_repos)


if __name__ == '__main__':
    start = time.time()
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('--pull', dest='pull')
    parser.add_argument('--branch', dest='branch')
    parser.add_argument('--reset-world', dest='reset_world', action='store_true')
    parser.add_argument('--upgrade-world', dest='upgrade_world', action='store_true')
    parser.add_argument('--upgrade-vendor', dest='upgrade_vendor', action='store_true')
    parser.add_argument('--config', dest='config', action='store_true')
    parser.add_argument('--world', dest='world', action='store_true')
    parser.add_argument('--landing', dest='landing', action='store_true')
    parser.add_argument('--errorpages', dest='errorpages', action='store_true')
    parser.add_argument('--l10n', '--i18n', dest='l10n', action='store_true')
    parser.add_argument('--extension-list', dest='extension_list', action='store_true')
    parser.add_argument('--no-log', dest='nolog', action='store_true')
    parser.add_argument('--force', dest='force', action='store_true')
    parser.add_argument('--force-upgrade', dest='force_upgrade', action='store_true')
    parser.add_argument('--files', dest='files')
    parser.add_argument('--folders', dest='folders')
    parser.add_argument('--lang', dest='lang', action=LangAction, help='l10n language(s) to rebuild, defaults to all')
    parser.add_argument('--versions', dest='versions', action=VersionsAction, default=[os.popen(f'/usr/local/bin/getMWVersion {get_environment_info().wikidbname}').read().strip()], help='version(s) to deploy')
    parser.add_argument('--show-tags', dest='show_tags', action='store_true', help='Show change tags for extension/skin upgrades')
    parser.add_argument('--skip-schema-confirm', dest='skip_schema_confirm', action='store_true', help='Skip confirm prompts for extensions with schema changes')
    parser.add_argument('--upgrade-extensions', dest='upgrade_extensions', action=UpgradeExtensionsAction, help='extension(s) to upgrade')
    parser.add_argument('--upgrade-skins', dest='upgrade_skins', action=UpgradeSkinsAction, help='skin(s) to upgrade')
    parser.add_argument('--upgrade-pack', dest='upgrade_pack', action=UpgradePackAction, choices=['bundled', 'mleb', 'socialtools', 'universalomega', 'wikitide'], help='pack of extensions/skins to upgrade')
    parser.add_argument('--servers', dest='servers', action=ServersAction, required=True, help='server(s) to deploy to')
    parser.add_argument('--ignore-time', dest='ignore_time', action='store_true')
    parser.add_argument('--port', dest='port')
    parser.add_argument('--apply-patches', dest='apply_patches', action=ApplyPatchesAction, help='repo(s) to apply patches to')

    run(parser.parse_args(), start)
