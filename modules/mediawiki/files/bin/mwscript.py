#! /usr/bin/python3
# -*- coding: utf-8 -*-
import sys
import os
if len(sys.argv) < 3:
    raise Exception("Not Enough Parameters")
script = sys.argv[1]
if len(script.split('/')) == 1:
    script = f'/srv/mediawiki/w/maintenance/{sys.argv[1]}'
else:
    scriptsplit = script.split('/')
    if scriptsplit[2] == "removePII.php":
        raise Exception("RemovePII can't be executed with mwscript")
    script = script = f'/srv/mediawiki/w/{scriptsplit[0]}/{scriptsplit[1]}/maintenance/{scriptsplit[2]}'
wiki = sys.argv[2]
if wiki in ("all", "foreachwikiindblist"):
    command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /srv/mediawiki/cache/databases.json {script}'
elif wiki in ("extension", "skin"):
    extension = input("Type the ManageWiki name of the extension or skin: ")
    generate = f'php /srv/mediawiki/w/extensions/MirahezeMagic/maintenance/generateExtensionDatabaseList.php --wiki=loginwiki --extension={extension}'
    command = f'sudo -u www-data /usr/local/bin/foreachwikiindblist /home/{os.getlogin()}/{extension}.json {script}'
else:
    command = f'sudo -u www-data php {script} --wiki={wiki}'
if len(sys.argv) == 4:
    command = f'{command} {sys.argv[3]}'
logcommand = f'/usr/local/bin/logsalmsg "{command}'
print("Will execute:")
if 'generate' in locals():
    print(generate)
print(command)
confirm = input("Type 'Y' to confirm: ")
if confirm.upper() == 'Y':
    if 'generate' in locals():
        os.system(generate)
    return_value = os.system(command)
    logcommand = f'{logcommand} (END - exit={str(return_value)})"'
    print(f'Logging via {logcommand}')
    os.system(logcommand)
    print('Done!')
else:
    print('Aborted!')
