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
  String $options                                                       = 'defaults',
  Enum['defined', 'present', 'unmounted', 'absent', 'mounted'] $ensure  = 'mounted',
) {

  include gluster::apt

  package { 'glusterfs-client':
      ensure   => installed,
      require  => Class['gluster::apt'],
  }

  exec { $title:
      command => "/bin/mkdir -p '${title}'",
      user    => 'root',
      group   => 'root',
      creates => $title,
      before  => Mount[$title],
  }

  if !defined(File['glusterfs.pem']) {
    file { 'glusterfs.pem':
      ensure => 'present',
      source => 'puppet:///ssl/certificates/wildcard.miraheze.org.crt',
      path   => '/etc/ssl/glusterfs.pem',
      owner  => 'root',
      group  => 'root',
    }
  }

  if !defined(File['glusterfs.key']) {
    file { 'glusterfs.key':
      ensure => 'present',
      source => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
      path   => '/etc/ssl/glusterfs.key',
      owner  => 'root',
      group  => 'root',
      mode   => '0660',
    }
  }

  if !defined(File['glusterfs.ca']) {
    file { 'glusterfs.ca':
      ensure => 'present',
      source => 'puppet:///ssl/ca/Sectigo.crt',
      path   => '/etc/ssl/glusterfs.ca',
      owner  => 'root',
      group  => 'root',
    }
  }

  if !defined(File['/var/lib/glusterd/secure-access']) {
    file { '/var/lib/glusterd/secure-access':
      ensure  => present,
      source  => 'puppet:///modules/gluster/secure-access',
      require => Package['glusterfs-client'],
    }
  }

  $base_options = "noauto,x-systemd.automount,attribute-timeout=200,entry-timeout=200,negative-timeout=60,fopen-keep-cache"

  $mount_options = $options ? {
      undef   => $base_options,
      default => "${base_options},${options}",
  }

  mount { $title:
    ensure   => $ensure,
    fstype   => 'glusterfs',
    remounts => false,
    device   => $volume,
    options  => $mount_options,
    require  => File['/var/lib/glusterd/secure-access']
  }
}
