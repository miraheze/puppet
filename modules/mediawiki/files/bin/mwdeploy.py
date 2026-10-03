#! /usr/bin/python3

# will eventually be moved to python-functions repository;
# prefer making changes there if possible

import argparse
import contextlib
import glob
import json
import os
import re
import shlex
import socket
import subprocess
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
COMPONENT_FETCH_BATCH_SIZE = 20
COMPONENT_FETCH_WORKERS = 10

_ANSI_RE = re.compile(r'\x1b\[[0-9;]*m')


class Console:
    RESET = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    CYAN = '\033[36m'

    enabled = sys.stdout.isatty() and not os.environ.get('NO_COLOR')

    @classmethod
    def _wrap(cls, text: str, *codes: str) -> str:
        if not cls.enabled:
            return text
        return f"{''.join(codes)}{text}{cls.RESET}"

    @classmethod
    def header(cls, text: str) -> str:
        return cls._wrap(text, cls.BOLD, cls.CYAN)

    @classmethod
    def bold(cls, text: str) -> str:
        return cls._wrap(text, cls.BOLD)

    @classmethod
    def dim(cls, text: str) -> str:
        return cls._wrap(text, cls.DIM)

    @classmethod
    def ok(cls, text: str) -> str:
        return cls._wrap(text, cls.GREEN)

    @classmethod
    def warn(cls, text: str) -> str:
        return cls._wrap(text, cls.YELLOW)

    @classmethod
    def fail(cls, text: str) -> str:
        return cls._wrap(text, cls.BOLD, cls.RED)

    @staticmethod
    def strip(text: str) -> str:
        """Removes color codes, for messages that end up somewhere other than a terminal."""
        return _ANSI_RE.sub('', text)


class ProgressBar:
    def __init__(self, total: int, label: str = '', width: int = 30):
        self.total = max(total, 1)
        self.label = label
        self.width = width

    def update(self, current: int, suffix: str = '') -> None:
        current = min(current, self.total)
        filled = int(self.width * current / self.total)
        bar = Console.ok('#' * filled) + Console.dim('-' * (self.width - filled))
        percent = int(100 * current / self.total)
        print(f'{self.label} [{bar}] {percent:3d}% ({current}/{self.total}) {suffix}'.rstrip())


class Sal:
    task: Optional[str] = None

    @classmethod
    def suffix(cls) -> str:
        return f' ({cls.task})' if cls.task else ''

    @staticmethod
    def plain(text: str) -> str:
        return Console.strip(text).removeprefix('==> ').replace('"', '')

    @classmethod
    def command(cls, message: str) -> str:
        return f'/usr/local/bin/logsalmsg {shlex.quote(cls.plain(message) + cls.suffix())}'


class ShellExecutor:
    """Runs shell commands."""

    @staticmethod
    def run(cmd: str) -> int:
        start = time.time()
        print(Console.dim(f'Execute: {cmd}'))
        ec = subprocess.run(cmd, shell=True).returncode
        elapsed = int(time.time() - start)
        status = Console.ok(f'Completed ({ec})') if ec == 0 else Console.fail(f'Completed ({ec})')
        print(f'{status} in {elapsed}s!')
        return ec

    @staticmethod
    def run_quiet(cmd: str) -> subprocess.CompletedProcess:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True)

    @staticmethod
    def ensure_all_zero(codes: list[int], nolog: bool = True, leave: bool = True) -> bool:
        for code in codes:
            if code != 0:
                if not nolog:
                    subprocess.run(Sal.command('DEPLOY ABORTED: Non-Zero Exit Code in prep, see output.'), shell=True)
                if leave:
                    print(Console.fail('Exiting due to non-zero status.'))
                    sys.exit(1)
                return True
        return False


def _load_mw_versions() -> dict:
    output = ShellExecutor.run_quiet('/usr/local/bin/getMWVersions').stdout.strip()
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


class Discovery:
    """Finds the valid choices for the options that take a list."""

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

    @staticmethod
    def versions() -> list[str]:
        return [version for version in versions.values() if os.path.exists(f'{STAGING_ROOT}/{version}')]

    @staticmethod
    def patch_paths() -> list[str]:
        return sorted({patch['path'] for patch in patches})


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
        result = ShellExecutor.run_quiet(f'git -C {repo_dir} --no-pager --git-dir={repo_dir}/.git diff --name-only HEAD@{{1}} HEAD')
        return [line.strip() for line in result.stdout.splitlines()]

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
              port: int = 443, use_cert: bool = True, exit_on_failure: bool = True) -> bool:
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
            print(Console.warn(f'Skipping canary check on {location} due to --force'))
            return True

        proto = 'https://' if port == 443 else 'http://'
        req = self._request(proto, domain, port, headers, verify, use_cert)

        up = (
            req.status_code == 200
            and 'mainpageisdomainroot' in req.text
            and (Debug is None or Debug in req.headers['X-Served-By'])
        )
        if not up:
            print(Console.dim(f'Status: {req.status_code}'))
            print(Console.dim(f'Text: {"miraheze" in req.text} \n {req.text}'))
            if 'X-Served-By' not in req.headers:
                req.headers['X-Served-By'] = 'None'
            print(Console.dim(f'Debug: {(Debug is None or Debug in req.headers["X-Served-By"])}'))
            print(Console.fail(f'Canary check failed for {location}. Aborting... - use --force to proceed'))
            message = Sal.command(f'DEPLOY ABORTED: Canary check failed for {location}')
            if nolog:
                print(message)
            else:
                subprocess.run(message, shell=True)
            if exit_on_failure:
                sys.exit(3)
            return False
        print(Console.ok(f'Canary check passed for {location}.'))
        return up


_default_canary_checker = CanaryChecker()


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

NEVER_DELETE = ('PrivateSettings.php', 'OAuth2.key')
NEVER_DELETE_GLOB = 'ExtensionMessageFiles-*.php'


class RsyncCommandBuilder:
    """Builds the rsync command lines used for both local staging and remote fleet syncs."""

    def __init__(self, deploy_user: str = DEPLOYUSER):
        self._deploy_user = deploy_user

    def build(self, time, source_root: str, dest_root: str, relative_paths: list[str],
              local: bool = True, server: Optional[str] = None) -> str:
        if not relative_paths:
            raise Exception('At least one path must be given.')
        params = '--inplace' if time else '--update'
        params += ' -r --delete'
        if 'config' in relative_paths:
            for protected in NEVER_DELETE:
                if os.path.exists(os.path.join(dest_root, 'config', protected)):
                    params += f' --exclude={protected}'
            if glob.glob(os.path.join(dest_root, 'config', NEVER_DELETE_GLOB)):
                params += f' --exclude="{NEVER_DELETE_GLOB}"'
        for path in relative_paths:
            if path != 'config' and os.path.exists(
                os.path.join(dest_root, path, 'LocalSettings.php')
            ):
                params += ' --exclude=LocalSettings.php'
        sources = ' '.join(f'{source_root}/./{path}' for path in relative_paths)

        if local:
            return f'sudo -u {self._deploy_user} rsync -R {params} --exclude=".*" {sources} {dest_root}/'

        if server:
            fqdn = socket.getfqdn()
            domain = '.'.join(fqdn.split('.')[1:])
            return f'sudo -u {self._deploy_user} rsync -R {params} -e "ssh -i {STAGING_ROOT}/deploykey" {sources} {self._deploy_user}@{server}.{domain}:{dest_root}/'

        raise Exception('Server must be specified for a remote rsync.')


_rsync_builder = RsyncCommandBuilder()


class GitCommandBuilder:
    """Builds the git command lines used to pull, reset, and patch a staged repo."""

    def __init__(self, paths: PathResolver, deploy_user: str = DEPLOYUSER):
        self._paths = paths
        self._deploy_user = deploy_user

    def pull(self, repo: str, submodules: bool = False, branch: Optional[str] = None,
             quiet: bool = True, version: str = '') -> str:
        extra = ''
        if submodules:
            extra += ' --recurse-submodules'
        if branch:
            extra += f' origin {branch}'
        if quiet:
            extra += ' --quiet'
        return f'sudo -H -u {self._deploy_user} git -C {self._paths.staging(repo, version)} pull{extra}'

    def reset_revert(self, repo: str, version: str = '') -> str:
        return f'sudo -H -u {self._deploy_user} git -C {self._paths.staging(repo, version)} reset --hard HEAD@{{1}}'

    def reset_hard(self, repo: str, version: str = '') -> str:
        return f'sudo -H -u {self._deploy_user} git -C {self._paths.staging(repo, version)} reset --hard'

    def apply(self, repo: str, patchfile: str, version: str = '', check: bool = False, reverse: bool = False) -> str:
        option = ' --check' if check else ' --index'
        if reverse:
            option += ' --reverse'
        return f'sudo -H -u {self._deploy_user} git -C {self._paths.staging(repo, version)} apply{option} {patchfile}'

    def fetch_pr(self, repo: str, pr_number: int, branch: str, version: str = '') -> str:
        # the leading + forces the fetch to update the local branch even when
        # the PR has been amended or rebased since the last time it was fetched
        return f'sudo -H -u {self._deploy_user} git -C {self._paths.staging(repo, version)} fetch origin +pull/{pr_number}/head:{branch}'

    def checkout(self, repo: str, branch: str, version: str = '') -> str:
        return f'sudo -H -u {self._deploy_user} git -C {self._paths.staging(repo, version)} checkout {branch}'

    def is_repo(self, repo: str, version: str) -> bool:
        return os.path.isdir(os.path.join(self._paths.staging(repo, version), '.git'))

    @staticmethod
    def strip_noise(text: str) -> str:
        lines = [
            line for line in text.splitlines()
            if not (line.strip().lower().startswith('warning:') and 'unable to access' in line.lower())
        ]
        return '\n'.join(lines).strip()


_git = GitCommandBuilder(_paths)


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
            # a core patch's path IS a specific MW version, so it can
            # only ever apply while that same version is being deployed
            return path == version
        staging_path = self._paths.staging(repo, version)
        if not staging_path.endswith(path):
            return False

        patch_versions = patch['versions']
        if 'all' in patch_versions:
            return True

        return version in patch_versions and staging_path.endswith(f'{version}/{path}')

    def _matching_patches(self, repo: str, version: str) -> list[dict]:
        return [patch for patch in self._patches if self._matches(patch, repo, version)]

    def has_patches(self, repo: str, version: str = '') -> bool:
        return bool(self._matching_patches(repo, version))

    def _apply_git(self, repo: str, patchfile: str, version: str) -> tuple[int, bool]:
        """Returns (exit code, changed). changed is False when the patch was
        already sitting in the tree, since nothing actually happened then."""
        name = os.path.basename(patchfile)
        check = ShellExecutor.run_quiet(self._git.apply(repo, patchfile, version, check=True))
        if check.returncode == 0:
            return ShellExecutor.run(self._git.apply(repo, patchfile, version)), True

        # a failed check doesn't always mean a real conflict. it can also mean
        # the patch is already sitting in the tree, so confirm that quietly
        # before bothering the user with anything.
        reverse_check = ShellExecutor.run_quiet(self._git.apply(repo, patchfile, version, check=True, reverse=True))
        if reverse_check.returncode == 0:
            print(Console.dim(f'{name} is already applied to {repo}. Skipping.'))
            return 0, False

        print(Console.fail(f'{name} does not apply to {repo}:'))
        detail = self._git.strip_noise(check.stderr)
        if detail:
            print(Console.dim(detail))
        return check.returncode, False

    def _apply_plain(self, repo: str, patchfile: str, version: str) -> tuple[int, bool]:
        # For non-git repos (like those installed via composer)
        name = os.path.basename(patchfile)
        staging_path = self._paths.staging(repo, version)
        already_applied = ShellExecutor.run_quiet(f'sudo -u {self._deploy_user} patch -p1 -N -d {staging_path} -i {patchfile} -r - --dry-run --reverse --silent')
        if already_applied.returncode == 0:
            print(Console.dim(f'{name} is already applied to {repo}. Skipping.'))
            return 0, False
        return ShellExecutor.run(f'sudo -u {self._deploy_user} patch -p1 -N -d {staging_path} -i {patchfile} -r -'), True

    def apply_all(self, repo: str, version: str = '') -> tuple[list[int], bool]:
        exitcodes = []
        changed = False
        is_git = self._git.is_repo(repo, version)
        to_apply = self._matching_patches(repo, version)

        for patch in to_apply:
            visibility = 'public' if patch['public'] else 'private'
            patchfile = f"{STAGING_ROOT}/patches/{visibility}/{patch['file']}"

            if not os.path.isfile(patchfile):
                print(Console.warn(f'WARNING: Patch file {patchfile} could not be found!'))
                continue

            code, patch_changed = self._apply_git(repo, patchfile, version) if is_git else self._apply_plain(repo, patchfile, version)

            if code == 0:
                exitcodes.append(code)
                changed = changed or patch_changed
                continue

            print(Console.fail(f"ERROR: Could not apply patch {patch['file']}"))
            if patch['failureStrategy'] == 'abort':
                print(Console.fail('Aborting!'))
                sys.exit(1)
            print(Console.warn('Skipping patch...'))

        return exitcodes, changed


_patch_applier = PatchApplier(patches, _paths, _git)


class RemoteDeployer:
    def __init__(self, rsync_builder: RsyncCommandBuilder, canary, hostname: str = HOSTNAME,
                 batch_size: int = 3, max_workers: int = 8):
        self._rsync_builder = rsync_builder
        self._canary = canary
        self._hostname = hostname
        self._batch_size = batch_size
        self._max_workers = max_workers

    def _deploy_to_server(self, server: str, time_flag, paths: list[str], root: str, envinfo: Environment,
                          nolog: bool, force: bool) -> tuple[str, int, bool]:
        cmd = self._rsync_builder.build(time_flag, root, root, paths, local=False, server=server)
        ec = ShellExecutor.run(cmd)
        healthy = self._canary.check(nolog, Debug=server, force=force, domain=envinfo.wikiurl, exit_on_failure=False)
        status = Console.ok('OK') if ec == 0 and healthy else Console.fail('FAIL')
        print(f'  {status}  {server}')
        return server, ec, healthy

    def _run_batch(self, batch: list[str], time_flag, paths: list[str], root: str, envinfo: Environment,
                   nolog: bool, force: bool) -> list[tuple[str, int, bool]]:
        if len(batch) == 1:
            return [self._deploy_to_server(batch[0], time_flag, paths, root, envinfo, nolog, force)]
        with ThreadPoolExecutor(max_workers=min(self._max_workers, len(batch))) as pool:
            futures = [
                pool.submit(self._deploy_to_server, server, time_flag, paths, root, envinfo, nolog, force)
                for server in batch
            ]
            return [future.result() for future in as_completed(futures)]

    def _batches(self, targets: list[str], batch: bool):
        """With batch off, every server goes out on its own, one at a time.
        With batch on, the first server goes out alone and everything after
        ships in fixed-size groups."""
        if not targets:
            return
        if not batch:
            for server in targets:
                yield [server]
            return
        yield [targets[0]]
        remaining = targets[1:]
        for start in range(0, len(remaining), self._batch_size):
            yield remaining[start:start + self._batch_size]

    def sync(self, time_flag, serverlist: list[str], paths: list[str], root: str, envinfo: Environment,
             nolog: bool, force: bool = False, batch: bool = False) -> int:
        label = paths[0] if len(paths) == 1 else f'{len(paths)} paths'
        print(Console.header(f'==> Deploying {label}'))
        targets = [server for server in serverlist if self._hostname != server.split('.')[0]]
        progress = ProgressBar(len(targets), label=Console.dim(label))
        deployed = 0

        codes: list[int] = []
        for group in self._batches(targets, batch):
            results = self._run_batch(group, time_flag, paths, root, envinfo, nolog, force)
            codes.extend(ec for _, ec, _ in results)
            deployed += len(group)
            progress.update(deployed)

            failed = [server for server, ec, healthy in results if ec != 0 or not healthy]
            if failed:
                print(Console.fail(f'Deploy or health check failed on: {", ".join(failed)}. Stopping before the remaining batches.'))
                print(Console.fail(f'Finished {label} deploys.'))
                sys.exit(3)

        print(Console.ok(f'Finished {label} deploys.'))
        if not codes:
            return 0
        return next((code for code in codes if code != 0), codes[-1])


_remote_deployer = RemoteDeployer(_rsync_builder, _default_canary_checker)


def _mark_all(loginfo: dict, key: str, actual, full) -> None:
    if key in loginfo and actual == full:
        loginfo[key] = 'all'


class DeploymentRunner:
    """Coordinates one mwdeploy invocation: local staging, then a fleet-wide rollout."""

    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.envinfo = get_environment_info()
        self._pr_checked_out = False

    def run(self, start: float) -> None:
        args = self.args
        Sal.task = args.task
        loginfo = self._build_loginfo()

        if args.new_install:
            synced = loginfo['servers']
            del loginfo['servers']
            self._log(Console.header(f'==> Starting new install of "{loginfo}" to {synced}'), args.nolog)
            fintext = f'finished new install of "{loginfo}" to {synced}'
            self._check_or_exit(self._new_install(), fintext)
            self._log(Console.ok(f'{fintext} - SUCCESS in {int(time.time() - start)}s'), args.nolog)
            return

        if args.upgrade_world and not args.reset_world:
            args.world = True
            args.pull = 'world'
            args.l10n = True
            args.ignore_time = True
            args.extension_list = True
            args.upgrade_vendor = True
            args.upgrade_extensions = Discovery.extensions(args.versions)
            args.upgrade_skins = Discovery.skins(args.versions)

        if len(args.servers) > 1:
            _mark_all(loginfo, 'servers', args.servers, self.envinfo.servers)

        use_version = bool(
            args.world or args.l10n or args.extension_list or args.reset_world
            or args.upgrade_extensions or args.upgrade_skins or args.upgrade_vendor or args.apply_patches,
        )

        if args.versions:
            _mark_all(loginfo, 'upgrade_extensions', args.upgrade_extensions, Discovery.extensions(args.versions))
            _mark_all(loginfo, 'upgrade_skins', args.upgrade_skins, Discovery.skins(args.versions))
            _mark_all(loginfo, 'apply_patches', args.apply_patches, Discovery.patch_paths())
            _mark_all(loginfo, 'versions', args.versions, Discovery.versions())
            if args.upgrade_pack:
                del loginfo['upgrade_extensions']
                del loginfo['upgrade_skins']
            if not use_version:
                del loginfo['versions']

        synced = loginfo['servers']
        del loginfo['servers']

        self._log(Console.header(f'==> Starting deploy of "{loginfo}" to {synced}'), args.nolog)
        fintext = f'finished deploy of "{loginfo}" to {synced}'

        self._check_or_exit(self.process(), fintext)

        if use_version:
            for version in args.versions:
                self._check_or_exit(self.process(version), fintext)

        fintext += f' - SUCCESS in {int(time.time() - start)}s'
        self._log(Console.ok(fintext), args.nolog)

    def _check_or_exit(self, exitcodes: list[int], fintext: str) -> None:
        if ShellExecutor.ensure_all_zero(exitcodes, leave=False):
            self._log(Console.fail(f'{fintext} - FAIL: {exitcodes}'), self.args.nolog)
            sys.exit(1)

    def _new_install(self) -> list[int]:
        args = self.args
        paths = list(Discovery.versions())
        paths += [self._relative(_paths.deployed(repo)) for repo in ('config', 'landing', 'errorpages')]
        paths.append('cache/databases.php')
        return [_remote_deployer.sync(True, args.servers, paths, DEPLOYED_ROOT, self.envinfo, args.nolog, force=True, batch=args.batch)]

    def process(self, version: str = '') -> list[int]:
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
            self._checkout_pr()

            if version:
                self._upgrade_vendor(version)
                for kind, items in (('extensions', args.upgrade_extensions), ('skins', args.upgrade_skins)):
                    if items:
                        self._upgrade_components(kind, items, version)

            for cmd in self.stage:  # setup env, git pull etc
                if 'composer' in cmd:
                    os.chdir(_paths.staging(version))
                self.exitcodes.append(ShellExecutor.run(cmd))
            ShellExecutor.ensure_all_zero(self.exitcodes, nolog=args.nolog)

            for option in options:  # configure rsync & custom data for repos
                if not options[option]:
                    continue
                if option == 'world':  # install steps for world
                    option = version
                    os.chdir(_paths.staging(version))
                    self.exitcodes.append(ShellExecutor.run(
                        f'sudo -u {DEPLOYUSER} http_proxy=http://bastion.fsslc.wtnet:8080 '
                        f'https_proxy=http://bastion.fsslc.wtnet:8080 composer update --no-dev --quiet',
                    ))
                    self._needs_version_cache_rebuild = True
                self.rsync.append(self._relative(_paths.deployed(option)))
            ShellExecutor.ensure_all_zero(self.exitcodes, nolog=args.nolog)

            # a version upgrade only needs one RebuildVersionCache run at the end,
            # no matter how many extensions, skins, or core itself were upgraded.
            if version and self._needs_version_cache_rebuild:
                self.rebuild.append(
                    f'sudo -u {DEPLOYUSER} MW_INSTALL_PATH={STAGING_ROOT}/{version} php {self._runner_staging}'
                    f'MirahezeMagic:RebuildVersionCache --save-gitinfo --version={version} '
                    f'--wiki={envinfo.wikidbname} --conf={STAGING_ROOT}/config/LocalSettings.php',
                )
                self.rsyncpaths.append(f'cache/{version}/gitinfo')

            if version and args.reset_world:  # complete reset_world by applying patches, after potential composer update
                applied = []
                for patch in patches:
                    if patch['path'] not in applied:
                        codes, _ = _patch_applier.apply_all(patch['path'], version)
                        self.exitcodes.extend(codes)
                        applied.append(patch['path'])
            ShellExecutor.ensure_all_zero(self.exitcodes, nolog=args.nolog)

            if version and args.apply_patches:
                self._apply_extra_patches(version)
            ShellExecutor.ensure_all_zero(self.exitcodes, nolog=args.nolog)

            if args.files and not version:  # specfic extra files
                for file in str(args.files).split(','):
                    self.rsync.append(file)
            if args.folders and not version:  # specfic extra folders
                for folder in str(args.folders).split(','):
                    self.rsync.append(folder)

            if args.extension_list and version:  # when adding skins/exts
                self.rebuild.append(f'sudo -u {DEPLOYUSER} php {self._runner}ManageWiki:RebuildExtensionListCache --wiki={envinfo.wikidbname} --cachedir={DEPLOYED_ROOT}/cache/{version}')

            if self.rsync:  # move staged content to live
                self.exitcodes.append(ShellExecutor.run(_rsync_builder.build(args.ignore_time, STAGING_ROOT, DEPLOYED_ROOT, self.rsync)))
            ShellExecutor.ensure_all_zero(self.exitcodes)

            if args.l10n and version:  # setup l10n
                lang = f'--lang={args.lang}' if args.lang else ''
                self.postinstall.append(f'sudo -u {DEPLOYUSER} php {self._runner}MirahezeMagic:MergeMessageFileList --quiet --wiki={envinfo.wikidbname} --extensions-dir={DEPLOYED_ROOT}/{version}/extensions:{DEPLOYED_ROOT}/{version}/skins --output {DEPLOYED_ROOT}/config/ExtensionMessageFiles-{version}.php')
                self.rebuild.append(f'sudo -u {DEPLOYUSER} php {self._runner}{DEPLOYED_ROOT}/{version}/maintenance/rebuildLocalisationCache.php {lang} --quiet --wiki={envinfo.wikidbname}')

            for cmd in self.postinstall:  # cmds to run after rsync & install (like mergemessage)
                self.exitcodes.append(ShellExecutor.run(cmd))
            ShellExecutor.ensure_all_zero(self.exitcodes, nolog=args.nolog)
            for cmd in self.rebuild:  # update ext list + l10n
                self.exitcodes.append(ShellExecutor.run(cmd))
            ShellExecutor.ensure_all_zero(self.exitcodes, nolog=args.nolog)

            # see if we are online - exit code 3 if not
            if args.port:
                _default_canary_checker.check(Debug=None, Host=envinfo.wikiurl, verify=False, force=args.force, nolog=args.nolog, port=args.port)
            else:
                _default_canary_checker.check(Debug=None, Host=envinfo.wikiurl, verify=False, force=args.force, nolog=args.nolog)

        # actually set remote lists
        for option in options:
            if options[option]:
                target = version if option == 'world' else option
                self.rsyncpaths.append(self._relative(_paths.deployed(target)))
        if args.files and not version:
            for file in str(args.files).split(','):
                self.rsyncpaths.append(file)
        if args.folders and not version:
            for folder in str(args.folders).split(','):
                self.rsyncpaths.append(folder)
        if args.extension_list and version:
            self.rsyncpaths.append(f'cache/{version}/extension-list.php')
        if args.l10n and version:
            self.rsyncpaths.append(f'cache/{version}/l10n')

        if self.rsyncpaths:
            self.exitcodes.append(_remote_deployer.sync(args.ignore_time, args.servers, self.rsyncpaths, DEPLOYED_ROOT, envinfo, args.nolog, force=args.force, batch=args.batch))

        self._print_summary()
        return self.exitcodes

    def _reset_state(self) -> None:
        self.exitcodes: list[int] = []
        self.rsyncpaths: list[str] = []
        self.rsync: list[str] = []
        self.rebuild: list[str] = []
        self.postinstall: list[str] = []
        self.stage: list[str] = []
        self.newschema: list[str] = []
        self.tagsinfo: list[str] = []
        self.warnings: dict[str, bool] = {}
        self._needs_version_cache_rebuild = False
        self._runner = ''
        self._runner_staging = ''

    @staticmethod
    def _relative(dest: str) -> str:
        return dest.removeprefix(f'{DEPLOYED_ROOT}/').rstrip('/')

    def _queue_rsync(self, relative: str) -> None:
        self.rsync.append(relative)
        self.rsyncpaths.append(relative)

    def _build_loginfo(self) -> dict:
        loginfo = {}
        for name, value in vars(self.args).items():
            if value is None or value is False:
                continue
            if name == 'pr_repo' and not self.args.pr:
                continue
            if name == 'task':
                continue
            if isinstance(value, list) and len(value) == 1:
                loginfo[name] = value[0]
            else:
                loginfo[name] = value
        return loginfo

    @staticmethod
    def _log(text: str, nolog: bool) -> None:
        if nolog:
            print(f'{text}{Sal.suffix()}')
        else:
            subprocess.run(Sal.command(text), shell=True)

    def _print_summary(self) -> None:
        if self.tagsinfo:
            print(Console.header('TAGS:'))
            for info in self.tagsinfo:
                print(f'  {info}')
        if self.newschema:
            print(Console.fail('WARNING: NEW SCHEMA CHANGES DETECTED:'))
            for schema in self.newschema:
                print(f'  {Console.warn(schema)}')

    def _pull_named_repos(self, version: str) -> None:
        if not self.args.pull:
            return
        for repo in str(self.args.pull).split(','):
            try:
                if repo == 'world':
                    if not version:
                        continue
                    repo = version
                self.exitcodes.append(ShellExecutor.run(_git.pull(repo, branch=self.args.branch)))
                codes, _ = _patch_applier.apply_all(repo)
                self.exitcodes.extend(codes)
            except KeyError:
                print(Console.fail(f'Failed to pull {repo} due to invalid name'))

    def _checkout_pr(self) -> None:
        if not self.args.pr or self._pr_checked_out:
            return
        repo = self.args.pr_repo
        branch = f'pr-{self.args.pr}'
        print(Console.header(f'==> Checking out PR #{self.args.pr} for {repo} as {branch}'))
        self.exitcodes.append(ShellExecutor.run(_git.fetch_pr(repo, self.args.pr, branch)))
        self.exitcodes.append(ShellExecutor.run(_git.checkout(repo, branch)))
        self._pr_checked_out = True

    def _upgrade_vendor(self, version: str) -> None:
        if not self.args.upgrade_vendor:
            return
        self.exitcodes.append(ShellExecutor.run(_git.reset_hard('vendor', version=version)))
        self.exitcodes.append(ShellExecutor.run(_git.pull('vendor', submodules=True, version=version)))
        codes, _ = _patch_applier.apply_all('vendor', version)
        self.exitcodes.extend(codes)
        if not self.args.world:
            self.stage.append(
                f'sudo -u {DEPLOYUSER} http_proxy=http://bastion.fsslc.wtnet:8080 '
                f'https_proxy=http://bastion.fsslc.wtnet:8080 composer update --no-dev --quiet',
            )
            self._queue_rsync(f'{version}/vendor')

    def _apply_extra_patches(self, version: str) -> None:
        for repo in self.args.apply_patches:
            if not _patch_applier.has_patches(repo, version):
                continue
            codes, _ = _patch_applier.apply_all(repo, version)
            self.exitcodes.extend(codes)
            self._queue_rsync(self._relative(_paths.deployed(repo, version)))

    def _upgrade_components(self, kind: str, items: list[str], version: str) -> None:
        # non-git repos (or ones missing entirely) are handled right away, since
        # there's nothing to fetch. everything else is queued up and fetched in
        # fixed-size batches.
        to_fetch = []
        for name in items:
            repo = f'{kind}/{name}'
            if not _git.is_repo(repo, version):
                print(Console.ok(f'Upgrading {name}'))
                codes, _ = _patch_applier.apply_all(repo, version)
                self.exitcodes.extend(codes)
                if not self.args.world:
                    self._queue_rsync(f'{version}/{repo}')
                continue

            if not os.path.exists(_paths.staging(repo, version)):
                print(Console.warn(f'{name} does not exist for {version}. Skipping...'))
                continue

            to_fetch.append(name)

        if not to_fetch:
            return

        print(Console.header(f'==> Fetching {kind} ({len(to_fetch)})'))
        total = len(to_fetch)
        progress = ProgressBar(total, label=Console.dim(kind))
        fetched_count = 0
        batch_size = COMPONENT_FETCH_BATCH_SIZE if self.args.batch else 1
        for start in range(0, total, batch_size):
            batch = to_fetch[start:start + batch_size]
            if self.args.batch:
                with ThreadPoolExecutor(max_workers=min(COMPONENT_FETCH_WORKERS, len(batch))) as pool:
                    fetched = list(pool.map(lambda name: self._fetch_component(kind, name, version), batch))
            else:
                fetched = [self._fetch_component(kind, name, version) for name in batch]

            # confirmation prompts, patch application, and rsync queueing all touch
            # shared state, so a batch is fully processed before the next one starts
            for name, repo, output, status, error in fetched:
                self._process_component_fetch(name, repo, output, status, error, version)

            fetched_count += len(batch)
            progress.update(fetched_count)

    @staticmethod
    def _fetch_component(kind: str, name: str, version: str):
        repo = f'{kind}/{name}'
        result = ShellExecutor.run_quiet(_git.pull(repo, submodules=True, quiet=False, version=version))
        return name, repo, result.stdout.strip(), result.returncode, result.stderr

    def _process_component_fetch(self, name: str, repo: str, output: str, status, error: str, version: str) -> None:
        args = self.args
        if status:
            if not args.force:
                self.exitcodes.append(status)
            print(Console.fail(f'Failed to upgrade {name} (exit code: {status}).'))
            if args.debug:
                detail = _git.strip_noise(error)
                if detail:
                    print(Console.dim(detail))
            return

        updated = args.force_upgrade or output != 'Already up to date.'
        applied_codes, patches_changed = _patch_applier.apply_all(repo, version)
        self.exitcodes.extend(applied_codes)

        # a patch can be added or changed without any upstream commit
        # existing yet, so an actually applied patch counts as a real change
        # too, even when git itself had nothing new to pull. a patch that
        # matched but was already sitting in the tree does not count, since
        # nothing on disk actually moved.
        changed = updated or patches_changed

        if updated:
            print(Console.ok(f'Upgrading {name}'))
        elif patches_changed:
            print(Console.dim(f'{name} already up to date. Applying patches...'))
        else:
            print(Console.dim(f'{name} already up to date.'))

        for file in ChangeTagger.files_of_type(repo, version, 'schema change'):
            if not args.skip_schema_confirm and name not in self.warnings:
                self.warnings[name] = True
                print(Console.warn('WARNING: upgrade contains schema changes.'))
                try:
                    if input(Console.bold('Type Y to confirm: ')).upper() != 'Y':
                        self.exitcodes.append(ShellExecutor.run(_git.reset_revert(repo, version)))
                        print(Console.warn('reverted'))
                        continue
                    self.newschema.append(f'{STAGING_ROOT}/{version}/{repo}/{file}')
                except KeyboardInterrupt:
                    ShellExecutor.run(_git.reset_revert(repo, version))
                    print(Console.warn('reverted'))
                    self._print_summary()
                    print(Console.fail('Operation aborted by user'))
                    sys.exit(1)

        if args.show_tags:
            tags = ChangeTagger.tags(repo, version)
            if tags:
                self.tagsinfo.append(f'Tags for {name}: {", ".join(sorted(tags))}')

        if changed and not args.world:
            self._queue_rsync(f'{version}/{repo}')
            self._needs_version_cache_rebuild = True


def task_id(value: str) -> str:
    if not re.fullmatch(r'T[0-9]+', value):
        raise argparse.ArgumentTypeError(f'invalid task ID {value!r}, expected something like T12345')
    return value


class UpgradeExtensionsAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):  # noqa: U100
        mw_versions = getattr(namespace, 'versions', None)
        if not mw_versions:
            parser.error('--versions is required when using --upgrade-extensions (--versions must come before --upgrade-extensions)')
        input_extensions = values.split(',')
        valid_extensions = Discovery.extensions(mw_versions)
        if 'all' in input_extensions:
            input_extensions = valid_extensions
        invalid_extensions = set(input_extensions) - set(valid_extensions)
        if invalid_extensions:
            parser.error(f'invalid extension choice(s): {", ".join(invalid_extensions)}')
        setattr(namespace, self.dest, sorted(input_extensions))


class UpgradeSkinsAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):  # noqa: U100
        mw_versions = getattr(namespace, 'versions', None)
        if not mw_versions:
            parser.error('--versions is required when using --upgrade-skins (--versions must come before --upgrade-skins)')
        input_skins = values.split(',')
        valid_skins = Discovery.skins(mw_versions)
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
        valid_versions = Discovery.versions()
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
        if not getattr(namespace, 'versions', None):
            parser.error('--versions is required when using --apply-patches (--versions must come before --apply-patches)')
        input_repos = values.split(',')
        if 'all' in input_repos:
            input_repos = Discovery.patch_paths()
        setattr(namespace, self.dest, input_repos)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('--pull', dest='pull')
    parser.add_argument('--branch', dest='branch')
    parser.add_argument('--pr', dest='pr', type=int, help='check out this PR number instead of the default branch, in the repo named by --pr-repo')
    parser.add_argument('--pr-repo', dest='pr_repo', default='config', help='repo --pr checks out a pull request branch in (default: config)')
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
    parser.add_argument('--versions', dest='versions', action=VersionsAction, default=[ShellExecutor.run_quiet(f'/usr/local/bin/getMWVersion {get_environment_info().wikidbname}').stdout.strip()], help='version(s) to deploy')
    parser.add_argument('--show-tags', dest='show_tags', action='store_true', help='Show change tags for extension/skin upgrades')
    parser.add_argument('--skip-schema-confirm', dest='skip_schema_confirm', action='store_true', help='Skip confirm prompts for extensions with schema changes')
    parser.add_argument('--upgrade-extensions', dest='upgrade_extensions', action=UpgradeExtensionsAction, help='extension(s) to upgrade')
    parser.add_argument('--upgrade-skins', dest='upgrade_skins', action=UpgradeSkinsAction, help='skin(s) to upgrade')
    parser.add_argument('--upgrade-pack', dest='upgrade_pack', action=UpgradePackAction, choices=['bundled', 'mleb', 'socialtools', 'universalomega', 'wikitide'], help='pack of extensions/skins to upgrade')
    parser.add_argument('--servers', dest='servers', action=ServersAction, required=True, help='server(s) to deploy to')
    parser.add_argument('--ignore-time', dest='ignore_time', action='store_true')
    parser.add_argument('--port', dest='port')
    parser.add_argument('--apply-patches', dest='apply_patches', action=ApplyPatchesAction, help='repo(s) to apply patches to')
    parser.add_argument('--batch', dest='batch', action='store_true', help='deploy to servers and fetch components in parallel batches instead of one at a time')
    parser.add_argument('--debug', dest='debug', action='store_true', help='show the underlying command output when a component fails to fetch')
    parser.add_argument('--task', dest='task', type=task_id, help='Phorge task ID to include in the log entries, e.g. T12345')
    parser.add_argument('--new-install', dest='new_install', action='store_true', help='mirror everything currently deployed onto a brand-new server (every version, config/landing/errorpages, and the database cache); ignores every deploy-selection flag, --servers/--batch/--task/--no-log still apply')
    return parser


def main() -> None:
    start = time.time()
    DeploymentRunner(build_parser().parse_args()).run(start)


if __name__ == '__main__':  # pragma: no cover
    main()
