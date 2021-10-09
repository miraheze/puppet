#! /usr/bin/python3
# -*- coding: utf-8 -*-
from os import system
system('sudo puppet agent --enable')
system('sudo puppet agent -tv')
system('logsalmsg enabled puppet')
