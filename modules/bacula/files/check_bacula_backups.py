#!/usr/bin/env python3
#
#   check_bacula_client  Nagios plugin to check Bacula client backups
#   Copyright (C) 2010  Tom Payne
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.


from datetime import datetime, timedelta
import argparse
import re
import sys
import time

import pexpect


OK, WARNING, CRITICAL, UNKNOWN = list(range(0, 4))
status_message = 'OK WARNING CRITICAL UNKNOWN'.split()

MULTIPLIERS = {'s': 1, 'm': 60, 'h': 3600, 'd': 86400, 'w': 604800}
DIVISORS = ((60, 'minutes'), (60, 'hours'), (24, 'days'), (7, 'weeks'))


class ParsePeriodAction(argparse.Action):
    def __init__(self, option_strings, dest, nargs=None, **kwargs):
        if nargs is not None:
            raise ValueError("nargs not allowed")
        super(ParsePeriodAction, self).__init__(option_strings, dest, **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):
	    m = re.match(r'(\d+(?:\.\d+)?)(%s)\Z' % '|'.join(list(MULTIPLIERS.keys())), values)
	    if not m:
	        raise ValueError('invalid period - %s' % values)
	    setattr(namespace, self.dest, timedelta(seconds=float(m.group(1)) * MULTIPLIERS[m.group(2)]))


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('-H', metavar='FD_NAME', dest='hostid', help='client file director name')
    parser.add_argument('-B', metavar='BACKUP_NAME', dest='backupid', help='backup job name')
    parser.add_argument('-w', metavar='PERIOD', dest='warning', action=ParsePeriodAction, help='generate warning if last successful backup older than PERIOD')
    parser.add_argument('-c', metavar='PERIOD', dest='critical', action=ParsePeriodAction, help='generate critical if last successful backup older than PERIOD')
    parser.add_argument('-b', metavar='PATH', dest='bconsole', help='path to bconsole')
    parser.set_defaults(bconsole='/usr/sbin/bconsole')
    options = vars(parser.parse_args())
    if not options['hostid'] or not options['backupid']:
      parser.error("-H and -B should be specified.")
    exit_status, message = OK, None
    child = pexpect.spawn(options['bconsole'], ['-n'])
    hostid = options['hostid']
    backupid = options['backupid']
    try:
        child.expect(r'\n\*')
        child.sendline('status client=%s' % hostid)
        if child.expect_list([re.compile(br'Terminated Jobs:'), re.compile(br'Error: Client resource .* does not exist.'), pexpect.TIMEOUT]):
            raise RuntimeError('Timeout or unknown client: %s' % hostid)
        child.expect(r'\n\*')
        r = re.compile(r'\s*(\d+)\s+(\S+)\s+(\S+)\s+(\d+\.\d+\s+[KMGTP]|\d+)\s+OK\s+(\S+\s+\S+)\s+%s' % re.escape(backupid))
        job_id = level = files = bytes = finished = None
        for line in child.before.splitlines():
            m = r.match(line.decode('utf-8'))
            if m:
                job_id = int(m.group(1))
                level = m.group(2)
                files = int(re.sub(r',', '', m.group(3)))
                bytes = re.sub(r'\s+', '', m.group(4))
                finished = datetime(*(time.strptime(m.group(5), '%d-%b-%y %H:%M')[0:6]))
        if job_id is None:
            raise RuntimeError('no terminated jobs')
        age = datetime.now() - finished
        if options['warning'] and age > options['warning']:
            exit_status = WARNING
        if options['critical'] and age > options['critical']:
            exit_status = CRITICAL
        age, units = 24.0 * 60 * 60 * age.days + age.seconds, 'seconds'
        for d, u in DIVISORS:
            if age < d:
                break
            else:
                age /= d
                units = u
        message = '%s, %d files, %sB, %s (%.1f %s ago)' % (level, files, bytes, finished, age, units)
    except RuntimeError:
        exit_status, message = (CRITICAL, str(sys.exc_info()[1]))
    child.sendeof()
    child.expect_list([pexpect.EOF, pexpect.TIMEOUT])
    print(('%s: %s' % (status_message[exit_status], message)))
    sys.exit(exit_status)


if __name__ == '__main__':
    main(sys.argv)
