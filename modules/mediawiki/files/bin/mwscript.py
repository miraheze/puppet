#! /usr/bin/python3

# will eventually be moved to python-functions repository;
# prefer making changes there if possible

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import socket
import subprocess
import sys
import time
from dataclasses import dataclass

DEPLOYUSER = 'www-data'
MEDIAWIKI_ROOT = '/srv/mediawiki'
HOSTNAME = socket.gethostname().split('.')[0]
WIKISUFFIX = 'wikibeta' if HOSTNAME.startswith('test') else 'wiki'

LONG_SCRIPTS = frozenset({
    'cargorecreatedata',
    'checkswiftcontainers',
    'compressold',
    'deletebatch',
    'importdump',
    'importimages',
    'nukens',
    'populatewikibasesitestable',
    'populatewikisettings',
    'purgelist',
    'rebuildall',
    'rebuildimages',
    'rebuildtextindex',
    'refreshlinks',
    'resetwikicaches',
    'runjobs',
})

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


class Sal:
    task: str | None = None

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
    def run(cmd: str, echo: bool = True) -> int:
        start = time.time()
        if echo:
            print(Console.dim(f'Execute: {cmd}'))
        ec = subprocess.run(cmd, shell=True).returncode
        elapsed = int(time.time() - start)
        status = Console.ok(f'Completed ({ec})') if ec == 0 else Console.fail(f'Completed ({ec})')
        print(f'{status} in {elapsed}s!')
        return ec

    @staticmethod
    def run_quiet(cmd: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True)


class UsageError(Exception):
    """Raised when the arguments given can not be turned into a command."""


@dataclass(frozen=True)
class CommandInfo:
    command: str
    generate: str | None
    long: bool
    nolog: bool
    confirm: bool


class CommandBuilder:
    """Turns parsed arguments into the shell command that gets run."""

    STATIC_DBLISTS = ('active', 'closed', 'deleted', 'inactive', 'upgrade-wikis')

    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.versions = self._load_versions()
        self.version_lists = tuple(f'{key}-wikis' for key in self.versions)
        self.db_lists = (*self.STATIC_DBLISTS, *self.version_lists)

    @staticmethod
    def _load_versions() -> dict[str, str]:
        output = ShellExecutor.run_quiet('/usr/local/bin/getMWVersions all').stdout.strip()
        return json.loads(output) if output else {}

    @staticmethod
    def is_long_script(script: str) -> bool:
        name = re.split(r'[:\\/]', script)[-1].removesuffix('.php')
        return name.lower() in LONG_SCRIPTS

    def _split_wiki(self) -> tuple[str, list[str]]:
        arguments = list(self.args.arguments)
        if self.args.extension:
            return '', arguments
        if not arguments:
            raise UsageError('Not enough arguments given.')
        first = arguments[0]
        if first.endswith(('wiki', 'wikibeta')) or first == 'all' or first in self.db_lists:
            return first, arguments[1:]
        raise UsageError(f'First argument should be a valid wiki if --extension is not given, got: {first}')

    def _resolve_version(self, wiki: str) -> str:
        if self.args.version:
            return str(self.args.version)
        if wiki in self.version_lists:
            version = self.versions.get(wiki.removesuffix('-wikis'), '')
        else:
            dbname = shlex.quote(wiki or 'default')
            version = ShellExecutor.run_quiet(f'sudo -u {DEPLOYUSER} /usr/local/bin/getMWVersion {dbname}').stdout.strip()
        if not version:
            raise UsageError('Could not determine the MediaWiki version, use --version.')
        return version

    def _script_target(self, version: str) -> tuple[str, str]:
        script = self.args.script
        root = f'{MEDIAWIKI_ROOT}/{version}'
        runner = f'{root}/maintenance/run.php'
        if not script.endswith('.php'):
            return runner, script
        parts = script.split('/')
        if len(parts) < 3:
            return runner, f'{root}/maintenance/{script}'
        if len(parts) > 3 and parts[2] in ('maintenance', 'scripts'):
            return runner, f'{root}/{script}'
        return runner, f'{root}/{parts[0]}/{parts[1]}/maintenance/{"/".join(parts[2:])}'

    def build(self) -> CommandInfo:
        args = self.args
        wiki, extra = self._split_wiki()
        runner, target = self._script_target(self._resolve_version(wiki))
        script = shlex.join([runner, target])
        prefix = f'sudo -u {DEPLOYUSER}'
        foreach = f'{prefix} /usr/local/bin/foreachwikiindblist'
        long = self.is_long_script(args.script)
        generate = None

        if wiki == 'all':
            long = True
            command = f'{foreach} {MEDIAWIKI_ROOT}/cache/databases.php {script}'
        elif wiki in self.db_lists:
            long = True
            dblist = shlex.quote(f'{MEDIAWIKI_ROOT}/cache/{wiki}.php')
            command = f'{foreach} {dblist} {script}'
        elif args.extension:
            long = True
            extension = shlex.quote(f'--extension={args.extension}')
            dblist = shlex.quote(f'/tmp/{args.extension}.php')
            generate = f'{prefix} php {shlex.quote(runner)} MirahezeMagic:GenerateExtensionDatabaseList --wiki=meta{WIKISUFFIX} {extension} --directory=/tmp'
            command = f'{foreach} {dblist} {script}'
        else:
            command = f'{prefix} php {script} {shlex.quote(f"--wiki={wiki}")}'

        if extra:
            command += f' {shlex.join(extra)}'
        return CommandInfo(command=command, generate=generate, long=long, nolog=args.nolog, confirm=args.confirm)


class ScriptRunner:
    """Confirms, logs and executes a built command."""

    def __init__(self, info: CommandInfo):
        self.info = info

    @staticmethod
    def _log(message: str, show: bool = False) -> None:
        cmd = Sal.command(message)
        if show:
            print(Console.dim(f'Logging via {cmd}'))
        ShellExecutor.run_quiet(cmd)

    def _confirmed(self) -> bool:
        if self.info.confirm:
            return True
        try:
            return input(Console.bold("Type 'Y' to confirm: ")).strip().upper() == 'Y'
        except (EOFError, KeyboardInterrupt):
            print()
            return False

    def run(self) -> int:
        info = self.info
        print(Console.header('==> Will execute:'))
        if info.generate:
            print(f'  {info.generate}')
        print(f'  {info.command}')

        if not self._confirmed():
            print(Console.warn('Aborted!'))
            return 1

        if info.long and not info.nolog:
            self._log(f'{info.command} (START)')

        generate = info.generate
        exit_code = ShellExecutor.run(generate, echo=False) if generate else 0
        if exit_code == 0:
            exit_code = ShellExecutor.run(info.command, echo=False)

        if not info.nolog:
            self._log(f'{info.command} (END - exit={exit_code})', show=True)

        print(Console.ok('Done!') if exit_code == 0 else Console.fail(f'Failed with exit code {exit_code}.'))
        return exit_code


def task_id(value: str) -> str:
    if not re.fullmatch(r'T[0-9]+', value):
        raise argparse.ArgumentTypeError(f'invalid task ID {value!r}, expected something like T12345')
    return value


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description='Run a MediaWiki maintenance script on a single wiki, on a database list, or on every wiki that has an extension or skin enabled. Options mwscript itself does not know are passed on to the script you are running.',
        epilog=(
            'examples:\n'
            '  mwscript ManageWiki:ResetWikiCaches metawiki --all-wikis\n'
            '  mwscript rebuildall.php all --yes\n'
            '  mwscript extensions/CheckUser/populateCheckUserTable.php metawiki --task=T12345\n'
            '  mwscript extensions/Translate/scripts/moveTranslatableBundle.php metawiki "Main Page 60" "Main Page 70" Admin --reason "Moved"'
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
    )
    parser.add_argument('script', help='script to run. Either a class name such as ManageWiki:ResetWikiCaches, a file in maintenance such as rebuildall.php, or a path such as extensions/Foo/bar.php')
    parser.add_argument('arguments', nargs='*', default=[], help='wiki database name, all, or a database list such as active (not needed with --extension), followed by any arguments for the script')
    parser.add_argument('--version', dest='version', help='MediaWiki version to run against, detected from the wiki when not given')
    parser.add_argument('--extension', '--skin', dest='extension', help='run on every wiki that has this extension or skin enabled instead of naming a wiki')
    parser.add_argument('--no-log', dest='nolog', action='store_true', help='do not log the run to the server admin log')
    parser.add_argument('--confirm', '--yes', '-y', dest='confirm', action='store_true', help='run without asking for confirmation first')
    parser.add_argument('--task', dest='task', type=task_id, help='Phorge task ID to include in the log entries, e.g. T12345')
    return parser


def get_args(argv: list[str] | None = None) -> argparse.Namespace:
    args, unknown = build_parser().parse_known_args(argv)
    args.arguments = [*args.arguments, *unknown]
    return args


def main(argv: list[str] | None = None) -> None:
    args = get_args(argv)
    Sal.task = args.task
    try:
        info = CommandBuilder(args).build()
    except UsageError as error:
        print(Console.fail(str(error)))
        sys.exit(2)
    sys.exit(ScriptRunner(info).run())


if __name__ == '__main__':  # pragma: no cover
    main()
