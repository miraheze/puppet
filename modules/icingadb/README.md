# icingadb

[![Build Status](https://github.com/voxpupuli/puppet-icingadb/workflows/CI/badge.svg)](https://github.com/voxpupuli/puppet-icingadb/actions?query=workflow%3ACI)
[![Release](https://github.com/voxpupuli/puppet-icingadb/actions/workflows/release.yml/badge.svg)](https://github.com/voxpupuli/puppet-icingadb/actions/workflows/release.yml)
[![Puppet Forge](https://img.shields.io/puppetforge/v/puppet/icingadb.svg)](https://forge.puppet.com/modules/puppet/icingadb)
[![puppet integration](http://www.puppetmodule.info/images/badge.png)](https://icinga.com/products/integrations/puppet)
[![Apache-2.0 License](https://img.shields.io/github/license/voxpupuli/puppet-icingadb.svg)](LICENSE)
[![Donated by Icinga](https://img.shields.io/badge/donated%20by-Icinga-fb7047.svg)](#transfer-notice)
[![Sponsored by NETWAYS](https://img.shields.io/badge/Sponsored%20by-NETWAYS%20GmbH-blue.svg)](https://www.netways.de)

![Icinga Logo](https://www.icinga.com/wp-content/uploads/2014/06/icinga_logo.png)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with icingadb](#setup)
    * [What icingadb affects](#what-icingadb-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with icingadb](#beginning-with-icingadb)
4. [Reference](#reference)
5. [Release notes](#release-notes)

## Description

This module manages the IcingaDB Redis server and the IcingaDB itself.

## Setup

### What the IcingaDB Puppet module supports

* Management of the IcingaDB Redis
* and the icingaDB itself

### Setup Requirements

This module supports:

* [puppet] >= 7.9.0 < 9.0.0

And requires:

* [puppetlabs/stdlib] >= 6.6.0 < 10.0.0
* [icinga/icinga] >= 2.9.0 < 8.0.0
* [puppet/redis] >= 8.2.0 < 13.0.0

### Beginning with icingadb

Add this declaration to your Puppetfile:
```
mod 'icingadb',
  :git => 'https://github.com/icinga/puppet-icingadb.git',
  :tag => 'v1.0.0'
```
Then run:
```
bolt puppetfile install
```

Or do a `git clone` by hand into your modules directory:
```
git clone https://github.com/voxpupuli/puppet-icingadb.git icingadb
```
Change to `icingadb` directory and check out your desired version:
```
cd icingadb
git checkout v1.0.0
```

## Reference

See [REFERENCE.md](https://github.com/voxpupuli/puppet-icingadb/blob/main/REFERENCE.md)

## Release Notes

This code is a very early release and may still be subject to significant changes.

## Transfer Notice

This plugin was originally authored by [Icinga](http://www.icinga.com).
The maintainer preferred that Vox Pupuli take ownership of the module for future improvement and maintenance.
Existing pull requests and issues were transferred over, please fork and continue to contribute here instead of Icinga.

Previously: https://github.com/icinga/puppet-icingadb
