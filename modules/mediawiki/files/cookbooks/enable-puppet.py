#! /usr/bin/python3

from os import system
system('sudo puppet agent --enable')
system('sudo puppet agent -tv')
system('logsalmsg enabled puppet')
