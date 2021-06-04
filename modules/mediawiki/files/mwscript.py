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
    script = script = f'/srv/mediawiki/w/{scriptsplit[0]}/{scriptsplit[1]}/maintenance/{scriptsplit[2]}'
wiki = sys.argv[2]
command = f'sudo -u www-data php {script} --wiki={wiki}'
if len(sys.argv) == 4:
    command = f'{command} {sys.argv[3]}'
logcommand = f'/usr/local/bin/logsalmsg "{command}"'
print("Will execute:")
print(command)
print(logcommand)
confirm = input("Type 'Y' to confirm: ")
if confirm == 'Y':
    os.system(command)
    os.system(logcommand)
    print('Done!')
else:
    print('Aborted!')
