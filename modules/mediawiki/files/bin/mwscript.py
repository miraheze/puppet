#! /usr/bin/python3

import argparse
import os


def run(args):
    longScripts = ('importDump.php', 'deleteBatch.php', 'importImages.php', 'rebuildall.php')
    long = False

    script = args.script
    if script in longScripts:
        long = True
    if len(script.split('/')) == 1:
        script = f'/srv/mediawiki/w/maintenance/{script}'
    else:
        scriptsplit = script.split('/')
        script = f'/srv/mediawiki/w/{scriptsplit[0]}/{scriptsplit[1]}/maintenance/{scriptsplit[2]}'
        if scriptsplit[2] in longScripts:
            long = True

    wiki = args.wiki
    if wiki == 'all':
        long = True
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json {script}'
    elif args.extension:
        long = True
        generate = f'php /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/generateExtensionDatabaseList.php --wiki=loginwiki --extension={args.extension}'
        command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /home/{os.getlogin()}/{extension}.json {script}'
    else:
        command = f'sudo -u www-data php {script} --wiki={wiki}'
    if args.arguments:
        command = f'{command} {args.arguments}'
    logcommand = f'/usr/local/bin/logsalmsg "{command}'
    print("Will execute:")
    if 'generate' in locals():
        print(generate)
    print(command)
    confirm = input("Type 'Y' to confirm: ")
    if confirm.upper() == 'Y':
        if long:
            os.system(f'{logcommand} (START)"')
        if 'generate' in locals():
            os.system(generate)
        return_value = os.system(command)
        logcommand = f'{logcommand} (END - exit={str(return_value)})"'
        print(f'Logging via {logcommand}')
        os.system(logcommand)
        print('Done!')
    else:
        print('Aborted!')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('script', required=True)
    parser.add_argument('wiki', required=True)
    parser.add_argument('arguments', nargs='*')
    parser.add_argument('--extension', '--skin', dest='extension')
    run(parser.parse_args())
