#! /usr/bin/python3

# will eventually be moved to python-functions repository;
# prefer making changes there if possible

from __future__ import annotations

import argparse
import os
import json
import sys
from typing import TypedDict


class CommandInfo(TypedDict):
    command: str
    generate: str | None
    long: bool
    nolog: bool
    confirm: bool


def syscheck(result: CommandInfo | int) -> CommandInfo:
    if isinstance(result, int):
        sys.exit(result)
    return result


def get_commands(args: argparse.Namespace) -> CommandInfo | int:
    mw_versions = os.popen('/usr/local/bin/getMWVersions all').read().strip()
    versions = {}
    if mw_versions:
        versions = json.loads(mw_versions)

    del mw_versions

    versionLists = tuple([f'{key}-wikis' for key in versions.keys()])
    validDBLists = (
        'active',
        'deleted',
    ) + versionLists

    longscripts = (
        'checkswiftcontainers',
        'compressold',
        'deletebatch',
        'importdump',
        'importimages',
        'nukens',
        'populatewikibasesitestable',
        'rebuildall',
        'rebuildimages',
        'rebuildtextindex',
        'refreshlinks',
        'runjobs',
        'purgelist',
        'cargorecreatedata',
    )

    long = False
    generate = None

    try:
        if args.extension:
            wiki = ''
        elif args.arguments[0].endswith('wiki') or args.arguments[0].endswith('wikibeta') or args.arguments[0] in [*['all'], *validDBLists]:
            wiki = args.arguments[0]
            args.arguments.remove(wiki)
            if args.arguments == []:
                args.arguments = False
        else:
            print(f'First argument should be a valid wiki if --extension not given DEBUG: {args.arguments[0]} / {args.extension} / {[*["all"], *validDBLists]}')
            return 2
    except IndexError:
        print('Not enough Arguments given.')
        return 2

    if not args.version:
        dbname = wiki
        if not dbname:
            dbname = 'default'
        args.version = os.popen(f'/usr/local/bin/getMWVersion {dbname}').read().strip()
        if wiki and wiki in versionLists:
            args.version = versions.get(wiki[:-6])

    script = args.script
    runner = f'/srv/mediawiki/{args.version}/maintenance/run.php '

    if script.endswith('.php'):  # assume class if not
        scriptsplit = script.split('/')
        if script.split('.')[0].lower() in longscripts:
            long = True
        if len(scriptsplit) == 1:
            script = f'{runner}/srv/mediawiki/{args.version}/maintenance/{script}'
        elif len(scriptsplit) == 2:
            script = f'{runner}/srv/mediawiki/{args.version}/maintenance/{scriptsplit[0]}/{scriptsplit[1]}'
            if scriptsplit[1].split('.')[0].lower() in longscripts:
                long = True
        else:
            script = f'{runner}/srv/mediawiki/{args.version}/{scriptsplit[0]}/{scriptsplit[1]}/maintenance/{scriptsplit[2]}'
            if scriptsplit[2].split('.')[0].lower() in longscripts:
                long = True
    else:
        if script.lower() in longscripts:
            long = True
        script = f'{runner}{script}'

    if wiki == 'all':
        long = True
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.php {script}'
    elif wiki and wiki in validDBLists:
        long = True
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/{wiki}.php {script}'
    elif args.extension:
        long = True
        generate = f'sudo -u www-data php {runner}MirahezeMagic:GenerateExtensionDatabaseList --wiki=loginwiki --extension={args.extension} --directory=/tmp'
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /tmp/{args.extension}.php {script}'
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
    parser.add_argument('--version', dest='version')
    parser.add_argument('--extension', '--skin', dest='extension')
    parser.add_argument('--no-log', dest='nolog', action='store_true')
    parser.add_argument('--confirm', '--yes', '-y', dest='confirm', action='store_true')

    args = parser.parse_known_args()[0]
    args.arguments += parser.parse_known_args()[1]
    return args


if __name__ == '__main__':
    run(syscheck(get_commands(get_args())))
