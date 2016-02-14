#!/usr/bin/env python
# Nagios Varnish Backend Check
# v1.1
# URL: www.admingeekz.com
# Contact: sales@admingeekz.com
#
#
# Copyright (c) 2013, AdminGeekZ Ltd
# All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#

import sys
import optparse
import subprocess

def runcommand(command, exit_on_fail=True):
    try:
      process = subprocess.Popen(command.split(" "), stdout=subprocess.PIPE)
      output, unused_err = process.communicate()
      retcode = process.poll()
      return output

    except OSError, e:
      print "Error: Executing command failed,  does it exist?"
      sys.exit(2)


def main(argv):
  o = optparse.OptionParser(conflict_handler="resolve", description="Nagios plugin to check varnish backend health.")
  o.add_option('-H', '--host', action='store', type='string', dest='host', default='127.0.0.1', help='The ip varnishadm is listening on')
  o.add_option('-P', '--port', action='store', type='int', dest='port', default=6082, help='The port varnishadm is listening on')
  o.add_option('-s', '--secret', action='store', type='string', dest='secret', default='/etc/varnish/secret', help='The path to the secret file')
  o.add_option('-p', '--path', action='store', type='string', dest='path', default='/usr/bin/varnishadm', help='The path to the varnishadm binary')

  options=o.parse_args()[0]
  command = runcommand("%(path)s -S %(secret)s -T %(host)s:%(port)s debug.health" % options.__dict__)
  backends = command.split("\n")
  backends_healthy, backends_sick = [], []
  for line in backends:
    if line.startswith("Backend") and line.find("test")==-1:
      if line.endswith("Healthy"):
        backends_healthy.append(line.split(" ")[1])
      else:
        backends_sick.append(line.split(" ")[1])
 
  if backends_sick:
    print "%s backends are down: %s" % (len(backends_sick), "".join(backends_sick))
    sys.exit(2)

  if not backends_sick and not backends_healthy:
    print "No backends were found."
    sys.exit(1)

  print "All %s backends are healthy" % (len(backends_healthy))
  sys.exit(0)


if __name__ == "__main__":
    main(sys.argv[1:])
