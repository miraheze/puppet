# puppet-chrony

[![License](https://img.shields.io/github/license/voxpupuli/puppet-chrony.svg)](https://github.com/voxpupuli/puppet-chrony/blob/master/LICENSE)
[![Build Status](https://github.com/voxpupuli/puppet-chrony/actions/workflows/ci.yml/badge.svg)](https://github.com/voxpupuli/puppet-chrony/actions/workflows/ci.yml)
[![Puppet Forge](https://img.shields.io/puppetforge/v/puppet/chrony.svg?style=flat)](https://forge.puppetlabs.com/puppet/chrony)
[![Puppet Forge - downloads](https://img.shields.io/puppetforge/dt/puppet/chrony.svg?style=flat)](https://forge.puppetlabs.com/puppet/chrony)
[![Puppet Forge - scores](https://img.shields.io/puppetforge/f/puppet/chrony.svg?style=flat)](https://forge.puppetlabs.com/puppet/chrony)

## Table of Contents

1. [Overview](#overview)
1. [Module Description - What the module does and why it is useful](#module-description)
1. [Setup - The basics of getting started with chrony](#setup)
   - [What chrony affects](#what-chrony-affects)
   - [Setup requirements](#setup-requirements)
   - [Beginning with chrony](#beginning-with-chrony)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Copyright and License](#copyright-and-license)

## Overview

### Chrony Puppet Module

Manage chrony time daemon on Archlinux and Redhat

## Module Description

The Chrony module handles running chrony in Archlinux and Redhat systems
with systemd.

## Setup

### What chrony affects

- chrony package.
- chrony configuration file.
- chrony key file.
- chrony service.

### Requirements

Please review `metadata.json` for a list of requirements.

### Beginning with chrony

`include 'chrony'` is all you need to get it running. If you
wish to pass in parameters like which servers to use
then you can use:

```puppet
class { 'chrony':
  servers => ['ntp1.corp.com', 'ntp2.corp.com' ],
}
```

## Usage

All interaction with the chrony module can be done through
the main chrony class.

### I just want chrony, what's the minimum I need?

```puppet
include 'chrony'
```

### I just want to tweak the servers, nothing else

```puppet
class { 'chrony':
  servers => [ 'ntp1.corp.com', 'ntp2.corp.com', ],
}
```

### I'd like to make sure a secret password is used for chronyc

```puppet
class { 'chrony':
  servers         => [ 'ntp1.corp.com', 'ntp2.corp.com', ],
  chrony_password => 'secret_password',
}
```

### I'd like to use NTP authentication

```puppet
class { 'chrony':
  keys    => ['25 SHA1 HEX:1dc764e0791b11fa67efc7ecbc4b0d73f68a070c'],
  servers => {
    'ntp1.corp.com' => ['key 25', 'iburst'],
    'ntp2.corp.com' => ['key 25', 'iburst'],
  },
}
```

### I'd like chronyd to auto generate a command key at startup

```puppet
class { 'chrony':
   chrony_password    => 'unset',
   config_keys_manage => false,
}
```

### Allow some hosts

```puppet
class { 'chrony':
  queryhosts  => [ '192.168/16', ],
}
```

### How to configure leap second

```puppet
class { 'chrony':
  leapsecmode  => 'slew',
  smoothtime   => '400 0.001 leaponly',
  maxslewrate  => 1000.0
}
```

### Enable chrony-wait.service

RedHat and Suse provide a default disabled `chrony-wait.service` to block the `time-sync.target`
until node is synchronised.

To enable it:

```puppet
class { 'chrony':
  wait_enable => true,
  wait_ensure => true,
}
```

## Reference

Reference documentation for the chrony module is generated using
[puppet-strings](https://puppet.com/docs/puppet/latest/puppet_strings.html) and
available in [REFERENCE.md](REFERENCE.md)

## Limitations

See `metadata.json` for supported and tested operating systems.

## Copyright and License

This module is distributed under the [Apache License 2.0](LICENSE). Copyright
belongs to the module's authors, including Niels Abspoel and
[others](https://github.com/voxpupuli/puppet-chrony/graphs/contributors).

The module was originally written by [Niels Abspoel](https://github.com/aboe76)
and released as [aboe76/chrony](https://forge.puppet.com/aboe/chrony).
Since version 0.4.0, it is maintained by [Vox Pupuli](https://voxpupuli.org/).
