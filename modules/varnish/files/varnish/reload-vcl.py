#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# VCL reloader for Varnish, adapted to current WMF-specific needs!
#
# Copyright 2018 Brandon Black
# Copyright 2018 Emanuele Rocca
# Copyright 2018 Wikimedia Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import os
import re
import time
import uuid
import argparse
import subprocess


def file_exists(fname):
    """Helper for argparse to do check if a filename argument exists"""
    if not os.path.exists(fname):
        raise argparse.ArgumentTypeError("{0} does not exist".format(fname))
    return fname


def parse_options():
    """Parse command-line options, return args hash"""
    parser = argparse.ArgumentParser(description="VCL Reloader")
    parser.add_argument('--file', '-f', dest="vcl_file", type=file_exists,
                        metavar="FILE", help="VCL file", required=True)
    parser.add_argument('--instance_name', '-n', dest="instance_name",
                        help="name of varnish instance", default='')
    parser.add_argument('--delay', '-d', type=int, default=5,
                        help="delay secs between vcl.load and vcl.use")
    parser.add_argument('--compile-only', '-c', action='store_true',
                        help="test compilation, but do not use")
    parser.add_argument('--autodiscard', '-a', action='store_true',
                        help="auto-discard all unused boot/reload VCLs")
    parser.add_argument('--start-child', action='store_true',
                        help="start varnish child process")

    return parser.parse_args()


def do_cmd(cmd):
    """echo + exec cmd with normal output, raises on rv!=0"""
    print('Executing: "{}"'.format(" ".join(cmd)))
    subprocess.check_call(cmd)


def get_cmd_output(cmd):
    """echo + exec cmd, return stdout. raises on rv!=0 w/ stderr in msg"""
    print('Executing: "{}"'.format(" ".join(cmd)))
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (p_out, p_err) = p.communicate()
    if p.returncode != 0:
        raise Exception("Command %s failed with exit code %i, stderr:\n%s" %
                        (" ".join(cmd), p.returncode, p_err))
    return p_out


def auto_discard(vadm_cmd):
    """
    Discard loaded VCLs such as:
        available   auto/warm          0 vcl-$(uuid)

    Do *not* try discarding the currently active VCL, eg:
        active      auto/warm          3 vcl-$(uuid)

    as well as VCLs with a label pointing to them:
        available   auto/warm          0 vcl-$(uuid) (1 label)

    and labels referenced somewhere:
        available  label/warm          0 wikimedia_misc -> vcl-$(uuid) (1 return(vcl))
    """
    # sleep is insurance against unknown varnish bugs if we move too fast from
    # "use" to "discard" and trip some race.
    time.sleep(1)

    vcl_list_cmd = vadm_cmd + ['vcl.list']
    for line in get_cmd_output(vcl_list_cmd).splitlines():
        match = re.match(r'^available\s+\S+\s+[0-9]+\s+(boot|vcl-\S+)$', line.decode("utf-8"))
        if match:
            vcl_discard_cmd = vadm_cmd + ['vcl.discard', match.group(1)]
            do_cmd(vcl_discard_cmd)


def load(vadm_cmd, filename):
    """Load the given VCL file. Return generated vcl_id."""
    vcl_id = 'vcl-%s' % str(uuid.uuid4())
    vcl_load_cmd = vadm_cmd + ['vcl.load', vcl_id, filename]

    do_cmd(vcl_load_cmd)
    return vcl_id


def main():
    args = parse_options()
    os.umask(0o022)

    vadm_cmd = ['/usr/bin/varnishadm']

    # Load main VCL file
    main_vcl_id = load(vadm_cmd, args.vcl_file)

    # Use main VCL file
    if not args.compile_only:
        time.sleep(args.delay)
        vcl_use_cmd = vadm_cmd + ['vcl.use', main_vcl_id]
        do_cmd(vcl_use_cmd)

        if args.autodiscard:
            auto_discard(vadm_cmd)

        if args.start_child:
            do_cmd(vadm_cmd + ["start"])


if __name__ == '__main__':
    main()
