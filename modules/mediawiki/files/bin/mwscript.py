#! /usr/bin/python3

import argparse
import os


def run(args: argparse.Namespace) -> None:

    longscripts = ('deleteBatch.php', 'importDump.php', 'importImages.php', 'nukeNS.php', 'rebuildall.php', 'refreshLinks.php', 'purgeList.php', 'cargoRecreateData.php')
    validDBLists = ('active', 'beta')

    script = args.script
    long = (script in longscripts)

    if len(script.split('/')) == 1:
        script = f'/srv/mediawiki/w/maintenance/{script}'
    else:
        scriptsplit = script.split('/')
        script = f'/srv/mediawiki/w/{scriptsplit[0]}/{scriptsplit[1]}/maintenance/{scriptsplit[2]}'
        long = (scriptsplit[2] in longscripts)

    validDBLists = ('active', 'beta')

    if args.arguments[0].endswith('wiki') or args.arguments in [*'all', *validDBLists]:
        wiki = args.arguments[0]
        args.arguments.remove(wiki)
        if args.arguments == []:
            args.arguments = False
    elif not args.extension:
        raise ValueError(f'First argument should be a valid wiki if --extension not given DEBUG: {args.arguments} / {args.extension}')
    else:
        wiki = ''

    if wiki == 'all':
        long = True
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json {script}'
    elif wiki in validDBLists:
        long = True
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/{wiki}.json {script}'
    elif args.extension:
        long = True
        generate = f'php /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/generateExtensionDatabaseList.php --wiki=loginwiki --extension={args.extension}'
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /home/{os.getlogin()}/{args.extension}.json {script}'
    else:
        command = f'sudo -u www-data php {script} --wiki={wiki}'
    if args.arguments:
        command += ' ' + ' '.join(args.arguments)

    logcommand = f'/usr/local/bin/logsalmsg "{command}'
    print('Will execute:')
    if 'generate' in locals():
        print(generate)
    print(command)
    if args.confirm or input("Type 'Y' to confirm: ").upper() == 'Y':
        if long and not args.nolog:
            os.system(f'{logcommand} (START)"')
        if 'generate' in locals():
            os.system(generate)
        return_value = os.system(command)
        logcommand += f' (END - exit={str(return_value)})"'
        if not args.nolog:
            print(f'Logging via {logcommand}')
            os.system(logcommand)
        print('Done!')
    else:
        print('Aborted!')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('script')
    parser.add_argument('arguments', nargs='*', default=[])
    parser.add_argument('--extension', '--skin', dest='extension')
    parser.add_argument('--no-log', dest='nolog', action='store_true')
    parser.add_argument('--confirm', '--yes', '-y', dest='confirm', action='store_true')

    args = parser.parse_known_args()[0]
    args.arguments += parser.parse_known_args()[1]

    run(args)
