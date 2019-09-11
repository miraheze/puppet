#
# == Class gluster::mount
#
# Mounts a Gluster volume
#
# === Parameters
#
# volume: the volume to mount, in "server:/volname" format
# log_level: the GlusterFS log level to use
# log_file: the file to which to log this volume
# transport: TCP or RDMA
# direct_io_mode: whether or not to use direct io mode
# readdirp: whether or not to use readdirp
# atboot: whether to add this volume to /etc/fstab
# options: a comma-separated list of GlusterFS mount options
# dump: enable or disable dump in /etc/fstab
# pass: the sequence value for fsck for this volume in /etc/fstab
# ensure: one of: defined, present, unmounted, absent, mounted
#
# === Examples
#
# gluster::mount { 'data1':
#   ensure    => present,
#   volume    => 'srv1.local:/data1',
#   transport => 'tcp',
#   atboot    => true,
#   dump      => 0,
#   pass      => 0,
# }
#
# === Authors
#
# Scott Merrill <smerrill@covermymeds.com>
#
# === Copyright
#
# Copyright 2014 CoverMyMeds, unless otherwise noted
#
# The MIT License (MIT)
#
# Copyright (c) 2014 Scott Merrill
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
define gluster::mount (
  String $volume,
  Variant[Enum['yes', 'no'], Boolean] $atboot                           = 'yes',
  String $options                                                       = 'defaults',
  Integer $dump                                                         = 0,
  Integer $pass                                                         = 0,
  Enum['defined', 'present', 'unmounted', 'absent', 'mounted'] $ensure  = 'mounted',
  Optional[String] $log_level                                           = undef,
  Optional[String] $log_file                                            = undef,
  Optional[String] $transport                                           = undef,
  Optional[String] $direct_io_mode                                      = undef,
  Optional[Boolean] $readdirp                                           = undef,
) {

  require('glusterfs-client')

  file { $title:
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '2755',
    require => Package['glusterfs-client'],
  }

  if $log_level {
    $ll = "log-level=${log_level}"
  } else {
    $ll = undef
  }

  if $log_file {
    $lf = "log-file=${log_file}"
  } else {
    $lf = undef
  }

  if $transport {
    $t = "transport=${transport}"
  } else {
    $t = undef
  }

  if $direct_io_mode {
    $dim = "direct-io-mode=${direct_io_mode}"
  } else {
    $dim = undef
  }

  if $readdirp {
    $r = "usereaddrip=${readdirp}"
  } else {
    $r = undef
  }

  $mount_options = [ $options, $ll, $lf, $t, $dim, $r, ]
  $_options = join(delete_undef_values($mount_options), ',')

  if !defined(File['/var/lib/glusterd/secure-access']) {
    file { '/var/lib/glusterd/secure-access':
      ensure  => present,
      content => '',
      require => Package['glusterfs-client'],
    }
  }

  mount { $title:
    ensure   => $ensure,
    fstype   => 'glusterfs',
    remounts => false,
    atboot   => $atboot,
    device   => $volume,
    dump     => $dump,
    pass     => $pass,
    options  => $_options,
    require => File['']
  }
}
