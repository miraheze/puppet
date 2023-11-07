#! /usr/bin/python3

from __future__ import annotations

import argparse
import os
import sys
from typing import TYPE_CHECKING, TypedDict
if TYPE_CHECKING:
    from typing import Optional


class CommandInfo(TypedDict):
    command: str
    generate: Optional[str]
    long: bool
    nolog: bool
    confirm: bool


def get_commands(args: argparse.Namespace) -> CommandInfo:
    validDBLists = ('active', 'beta')
    longscripts = ('compressOld.php', 'deleteBatch.php', 'importDump.php', 'importImages.php', 'nukeNS.php', 'rebuildall.php', 'rebuildImages.php', 'refreshLinks.php', 'runJobs.php', 'purgeList.php', 'cargoRecreateData.php')
    long = False
    generate = None
    try:
        if args.extension:
            wiki = ''
        elif args.arguments[0].endswith('wiki') or args.arguments[0] in [*['all'], *validDBLists]:
            wiki = args.arguments[0]
            args.arguments.remove(wiki)
            if args.arguments == []:
                args.arguments = False
        else:
            print(f'First argument should be a valid wiki if --extension not given DEBUG: {args.arguments[0]} / {args.extension} / {[*["all"], *validDBLists]}')
            sys.exit(2)
    except IndexError:
        print('Not enough Arguments given.')
        sys.exit(2)
    script = args.script
    if not script.endswith('.php'):
        if not args.runner:
            print('Error: Specifiy --use-runner or --140 to enable MaintenanceRunner')
            sys.exit(2)
        if args.runner and not args.confirm:
            print(f'WARNING: Please log usage of {longscripts}. Support for longscripts has not been added')
            print('WARNING: Use of classes is not well tested. Please use with caution.')
            if input("Type 'Y' to confirm (or any other key to stop - rerun without --140/--use-runner): ").upper() != 'Y':
                sys.exit(2)
    if args.runner:
        runner = '/srv/mediawiki/w/maintenance/run.php '
    else:
        runner = ''
    if script.endswith('.php'):  # assume class if not
        scriptsplit = script.split('/')
        if script in longscripts:
            long = True
        if len(scriptsplit) == 1:
            script = f'{runner}/srv/mediawiki/w/maintenance/{script}'
        elif len(scriptsplit) == 2:
            script = f'{runner}/srv/mediawiki/w/maintenance/{scriptsplit[0]}/{scriptsplit[1]}'
            if scriptsplit[1] in longscripts:
                long = True
        else:
            script = f'{runner}/srv/mediawiki/w/{scriptsplit[0]}/{scriptsplit[1]}/maintenance/{scriptsplit[2]}'
            if scriptsplit[2] in longscripts:
                long = True
    else:
        script = f'{runner}{script}'

    if wiki == 'all':
        long = True
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json {script}'
    elif wiki in validDBLists:
        long = True
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/{wiki}.json {script}'
    elif args.extension:
        long = True
        generate = f'php {runner}/srv/mediawiki/w/extensions/MirahezeMagic/maintenance/generateExtensionDatabaseList.php --wiki=loginwiki --extension={args.extension}'
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /home/{os.getlogin()}/{args.extension}.json {script}'
    else:
        command = f'sudo -u www-data php {script} --wiki={wiki}'
    if args.arguments:
        command += ' ' + ' '.join(args.arguments)
    return {'long': long, 'generate': generate, 'command': command, 'nolog': args.nolog, 'confirm': args.confirm}


def run(info: CommandInfo) -> None:  # pragma: no cover
    logcommand = f'/usr/local/bin/logsalmsg "{info["command"]}'
    print('Will execute:')
    if info['generate']:
        print(info['generate'])
    print(info['command'])
    if info['confirm'] or input("Type 'Y' to confirm: ").upper() == 'Y':
        if info['long'] and not info['nolog']:
            os.system(f'{logcommand} (START)"')
        if info['generate']:
            os.system(info['generate'])  # type: ignore
        return_value = os.system(info['command'])
        logcommand += f' (END - exit={str(return_value)})"'
        if not info['nolog']:
            print(f'Logging via {logcommand}')
            os.system(logcommand)
        print('Done!')
    else:
        print('Aborted!')


def get_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Run a MediaWiki Script')
    parser.add_argument('script')
    parser.add_argument('arguments', nargs='*', default=[])
    parser.add_argument('--extension', '--skin', dest='extension')
    parser.add_argument('--no-log', dest='nolog', action='store_true')
    parser.add_argument('--confirm', '--yes', '-y', dest='confirm', action='store_true')
    parser.add_argument('--use-runner', '--140', dest='runner', action='store_true')

    args = parser.parse_known_args()[0]
    args.arguments += parser.parse_known_args()[1]
    return args


if __name__ == '__main__':

    run(get_commands(get_args()))
