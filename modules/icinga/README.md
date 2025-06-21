# icinga

[![Build Status](https://github.com/voxpupuli/puppet-icinga/workflows/CI/badge.svg)](https://github.com/voxpupuli/puppet-icinga/actions?query=workflow%3ACI)
[![Release](https://github.com/voxpupuli/puppet-icinga/actions/workflows/release.yml/badge.svg)](https://github.com/voxpupuli/puppet-icinga/actions/workflows/release.yml)
[![Puppet Forge](https://img.shields.io/puppetforge/v/puppet/icinga.svg)](https://forge.puppet.com/modules/puppet/icinga)
[![puppet integration](http://www.puppetmodule.info/images/badge.png)](https://icinga.com/products/integrations/puppet)
[![Apache-2.0 License](https://img.shields.io/github/license/voxpupuli/puppet-icinga.svg)](LICENSE)
[![Donated by Icinga](https://img.shields.io/badge/donated%20by-Icinga-fb7047.svg)](#transfer-notice)
[![Sponsored by NETWAYS](https://img.shields.io/badge/Sponsored%20by-NETWAYS%20GmbH-blue.svg)](https://www.netways.de)

[Icinga Logo](https://www.icinga.com/wp-content/uploads/2014/06/icinga_logo.png)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with icinga](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with icinga](#beginning-with-icinga)
3. [Usage - Configuration options and additional functionality](#usage)
    * [Enable and disable repositories](#enable-and-disable-repositories)
    * [Installing from non upstream repositories](#Installing from Non-Upstream Repositories)
4. [Reference](#reference)


## Description

This module provides several non private helper classes for the other official Icinga modules:

* [icinga2](https://github.com/voxpupuli/puppet-icinga2)
* [icingadb](https://github.com/voxpupuli/puppet-icingadb)
* [icingaweb2](https://github.com/voxpupuli/puppet-icingaweb2)

### How to use the classes for Icinga Web or any database use on Ubuntu Noble

To get Icinga Web 2 running on Ubutunt Noble use puppet-php >=8.3.0 and set:

```yaml
php::globals::php_version: '8.3'
```

The current MariaDB logs to syslog by default so set:

```yaml
mysql::server::override_options:
  mysqld:
    log-error: ~
```

This disables the logging to file and the requirement and management of an existing directory /var/log/mysql.

If using PostgreSQL you have to set the version to '16':

```yaml
---
postgresql::globals::version: '16'
```

### How to use the classes for Icinga Web or databases with MariaDB on Debian Bookwork

To get Icinga Web 2 running on Debian Bookworm use puppet-php >=8.2.0 (no longer necessary if puppet-php >= 10.2.0 is used) and set:

```yaml
php::globals::php_version: '8.2'
```

The current MariaDB logs to syslog by default so set:

```yaml
mysql::server::override_options:
  mysqld:
    log-error: ~
```

This disables the logging to file and the requirement and management of an existing directory /var/log/mysql.

## Setup

### What the Icinga Puppet module supports

* [icinga::repos] involves the needed repositories to install icinga2, icingadb and icingaweb2:
    * The Icinga Project repository for the stages: stable, testing or nightly builds
    * EPEL repository for RHEL simular platforms
    * Backports repository for Debian and Ubuntu
    * NETWAYS extras repository for Icinga Web 2
    * NETWAYS plugins repository with some additional monitoring plugins
* Classes to manage and setup an Icinga environment much easier:
    * [icinga::server] setups an Icinga 2 including CA, config server, zones and workers aka satellites
    * [icinga::worker] installs an Icinga 2 worker aka satellite
    * [icinga::ido] configures the IDO backend including the database
    * [icinga::web] manages Icinga Web 2, an Apache and a PHP-FPM

### Setup Requirements

The requirements depend on the class to be used.

### Beginning with icinga

Add this declaration to your Puppetfile:

```
mod 'icinga',
  :git => 'https://github.com/icinga/puppet-icinga.git',
  :tag => 'v2.5.0'
```

Then run:

```
bolt puppetfile install
```

Or do a `git clone` by hand into your modules directory:

```
git clone https://github.com/icinga/puppet-icinga.git icinga
```

Change to `icinga` directory and check out your desired version:

```
cd icinga
git checkout v2.5.0
```

## Usage

### icinga::repos

The class supports:

* [puppet] >= 7.9.0 < 9.0.0

And requires:

* [puppetlabs/stdlib] >= 6.6.0 < 10.0.0
* [puppetlabs/apt] >= 9.2.0 < 10.0.0
* [puppet/zypprepo] >= 4.0.0 < 6.0.0
* [puppetlabs/yumrepo_core] >= 1.1.0 < 3.0.0

By default the upstream Icinga repository for stable release are involved.

```puppet
include icinga::repos
```

To setup the testing repository for release candidates use instead:

```puppet
class { 'icinga::repos':
  manage_stable  => false,
  manage_testing => true,
}
```

Or the nightly builds:

```puppet
class { 'icinga::repos':
  manage_stable  => false,
  manage_nightly => true,
}
```

Other possible needed repositories like EPEL on RHEL or the Backports on Debian can also be involved:

```puppet
class { 'icinga::repos':
  manage_epel         => true,
  configure_backports => true,
}
```

The prefix `configure` means that the repository is not manageable by the module. But backports can be configured by the class apt::backports, that is used by this module.

#### Enable and Disable Repositories

When manage is set to `true` for a repository the ressource is managed and the repository is enabled by default. To switch off a repository again, it still has to be managed and the corresponding parameter has to set via hiera. The module does a deep merge lookup for a hash named `icinga::repos`. Allowed keys are:

* icinga-stable-release
* icinga-testing-builds
* icinga-snapshot-builds
* epel (only on RHEL platforms)
* powertools (only RHEL 8 platforms)
* crb (only RHEL 9 platforms)
* netways-plugins
* netways-extras

An example for Yum or Zypper based platforms to change from stable to testing repo:

```yaml
---
icinga::repos::manage_testing: true
icinga::repos:
  icinga-stable-release:
    enabled: 0
```

Or on Apt based platforms:

```yaml
---
icinga::repos::manage_testing: true
icinga::repos:
  icinga-stable-release:
    ensure: absent
```

#### Configure Icinga subscription repositories

For some time now, access to current RPM packages on Icinga has required a paid [subscription](https://icinga.com/subscription). Unfortunately, using older package versions for an Icinga server is not provided for in this project.

A subscription is required, it is configured as follows, e.g. in hiera:

```yaml
---
icinga::repos:
  icinga-stable-release:
    baseurl: 'https://packages.icinga.com/subscription/rhel/$releasever/release/'
    username: <username>
    password: <password>
```

#### Installing from Non-Upstream Repositories

To change to a non upstream repository, e.g. a local mirror, the repos can be customized via hiera. The module does a deep merge lookup for a hash named `icinga::repos`. Allowed keys are:

* icinga-stable-release
* icinga-testing-builds
* icinga-snapshot-builds
* epel (only on RHEL Enterprise platforms)
* powertools (only RHEL 8 platforms)
* crb (only RHEL 9 platforms)
* netways-plugins
* netways-extras

An example to configure a local mirror of the stable release:

```yaml
---
icinga::repos:
  icinga-stable-release:
    baseurl: 'https://repo.example.com/icinga/epel/$releasever/release/'
    gpgkey: https://repo.example.com/icinga/icinga.key
```

IMPORTANT: The configuration hash depends on the platform an requires one of the following resources:

* apt::source (Debian family, https://forge.puppet.com/puppetlabs/apt)
* yumrepo (RedHat family, https://forge.puppet.com/puppetlabs/yumrepo_core)
* zypprepo (SUSE, https://forge.puppet.com/puppet/zypprepo)

Also the Backports repo on Debian can be configured like the apt class of course, see https://forge.puppet.com/puppetlabs/apt to configure the class `apt::backports` via Hiera.

As an example, how you configure backports on a debian squeeze. For squeeze the repository is already moved to the unsupported archive:

```yaml
---
apt::confs:
  no-check-valid-until:
    content: 'Acquire::Check-Valid-Until no;'
    priority: 99
    notify_update: true
apt::backports::location: 'https://archive.debian.org/debian'
```

### icinga::server / icinga::worker / icinga::agent

The class supports:

* [puppet] >= 7.9.0 < 9.0

And requires:

* [icinga/icinga2] >= 3.1.0 < 7.0.0

Setting up a Icinga Server with a CA and to store configuration:

```
class { 'icinga::server':
  ca            => true,
  ticket_salt   => Sensitive('supersecret'),
  config_server => true,
  workers       => { 'dmz' => { 'endpoints' => { 'worker.example.org' => { 'host' => '172.16.2.11' }}, }},
  global_zones  => [ 'global-templates', 'linux-commands', 'windows-commands' ],
}
```

Addtition a connection to a worker is configured. By default the zone for the server is named `main`. When `config_server` is enabled directories are managed for all zones, including the worker and global zones.

IMPORTANT: A alpha numeric String has to be set to `ticket_salt` in Hiera to protect the CA! An alternative is to set `icinga::ticket_salt` in a hiera common section for all agents, workers and servers.

The associated worker could look like this:

```
class { 'icinga::worker':
  ca_server        => '172.16.1.11',
  zone             => 'dmz',
  parent_endpoints => { 'server.example.org' => { 'host' => '172.16.1.11', }, },
  global_zones     => [ 'global-templates', 'linux-commands', 'windows-commands' ],
}
```

If the worker doesn't have a certificate, it sends a certificate request to the CA on the host `ca_server`. The default parent zone is `main`. Thus, only the associated endpoint has to be defined.

If `icinga::ticket_salt` is also set in Hiera for the worker, he's automatically sent a certificate. Otherwise the request will be saved on the CA server and must be signed manually.

Both, server and workers, can operated with a parnter in the same zone to share load. The endpoint of the respective partner is specified as an Icinga object in `colocation_endpoints`.

```puppet
colocation_endpoints => { 'server2.example.org' => { 'host' => '172.16.1.12', } },
```

Of course, the second endpoint must also be specified in the respective `parent_endpoints` of the worker or agent.

An agent is very similar to a worker, only it has no parameter `colocation_endpoints`:

```puppet
class { 'icinga::agent':
  ca_server        => '172.16.1.11',
  parent_endpoints => { 'worker.example.org' => { 'host' => '172.16.2.11', }, } },
  global_zones     => [ 'linux-commands' ],
}
```

NOTICE: To switch off the package installation via chocolatey on windows, `icinga2::manage_packgaes` must be set to `false` for the corresponding hosts in Hiera. That works only on Windows, on Linux package installation is always used.


#### icinga::db

The class supports:

* [puppet] >= 7.9.0 < 9.0

Ands requires:

* [puppetlabs/mysql] >= 10.9.0 < 16.0.0
* [puppetlabs/postgresql] >= 7.0.0 < 11.0.0
* [icinga/icinga2] >= 3.1.0 < 7.0.0
* [icinga/icingadb] >= 2.1.0 < 4.0.0

To activate and configure the IcingaDB (usally on a server) do:

```puppet
class { 'icinga::db':
  db_type         => 'pgsql',
  db_host         => 'localhost',
  db_pass         => Sensitive('icingadb'),
  manage_database => true,
  manage_redis    => true,
  manage_feature  => true,
}
```

Setting `manage_database` to `true` also setups a database as specified in `db_type` including database for the IcingaDB. The same applies to `manage_redis` and the required Redis cache. With `manage_feature` the Icinga 2 feature for the IcingaDB is additionally activated. The latter two are switched on by default.

#### icinga::ido

The class supports:

* [puppet] >= 7.9.0 < 9.0

Ands requires:

* [puppetlabs/mysql] >= 10.9.0 < 17.0.0
* [puppetlabs/postgresql] >= 7.0.0 < 11.0.0
* [icinga/icinga2] >= 3.1.0 < 7.0.0

To activate and configure the IDO feature (usally on a server) do:

```puppet
class { 'icinga::ido':
  db_type         => 'pgsql',
  db_host         => 'localhost',
  db_pass         => Sensitive('icinga2'),
  manage_database => true,
}
```

Setting `manage_database` to `true` also setups a database as specified in `db_type` including database for the IDO. Supported are `pgsql` for PostgreSQL und `maysql` for MariaDB. By default the database name is set to `icinga2` and the user to `icinga2`.

### icinga::web

The class supports:

* [puppet] >= 7.9.0 < 9.0

And requires:

* [puppetlabs/mysql] >= 10.9.0 < 17.0.0
* [puppetlabs/postgresql] >= 7.0.0 < 11.0.0
* [icinga/icingaweb2] >= 3.7.0 < 6.0.0
* [icinga/icinga2] >= 3.1.0 < 7.0.0
* [puppetlabs/apache] >= 5.8.0 < 13.0.0
* [puppet/php] >= 8.0.0 < 11.0.0

A Icinga Web 2 with an Apache and PHP-FPM can be managed as follows:

```puppet
class { 'icinga::web':
  db_type         => 'pgsql',
  db_host         => 'localhost',
  db_pass         => Sensitive('supersecret'),
  manage_database => true,
  api_pass        => $icinga::server::web_api_pass,
}
```

Setting `manage_database` to `true`, a database of the specified type is also installed here. It is used to save user settings for the users of the Icinga Web 2 and serves as a backend for managing Icinga Web 2 users and user groups.

IMPORTANT: If you plan tu use icingacli as plugin, e.g. director health checks, businessprocess checks or vspheredb checks, set the parameter `run_web => true` for `icinga::server` on the same host `icinga::web` is declared. That put the Icinga user to the group `icingaweb2` and restart the icinga2 process if necessary.

#### icinga::web::icingadb

If the Icinga Web 2 is operated on the same host as the IcingaDB, the required user credentials can be accessed, otherwise they must be specified explicitly.

```puppet
class { 'icinga::web::icingadb':
  db_type => $icinga::db::db_type,
  db_host => $icinga::db::db_host,
  db_name => $icinga::db::db_name,
  db_user => $icinga::db::db_user,
  db_pass => $icinga::db::db_pass,
}
```

IMPORTANT: Must be declared on the same host as `icinga::web`.

#### icinga::web::monitoring

If the Icinga Web 2 is operated on the same host as the IDO, the required user credentials can be accessed, otherwise they must be specified explicitly.

```puppet
class { 'icinga::web::monitoring':
  db_type => $icinga::ido::db_type,
  db_host => $icinga::ido::db_host,
  db_pass => $icinga::ido::db_pass,
}
```

IMPORTANT: Must be declareid on the same host as `icinga::web`.

#### icinga::web::director

Install and manage the famous Icinga Director and the required database. A graphical addon to manage your monitoring environment, the hosts, services, notifications etc.

Here an example with an PostgreSQL database on the same host:

```puppet
class { 'icinga::web::director':
  db_type         => 'pgsql',
  db_host         => 'localhost',
  db_pass         => Sensitive('supersecret'),
  manage_database => true,
  endpoint        => $facts['networking']['fqdn'],
  api_host        => 'localhost',
  api_pass        => $icinga::server::director_api_pass,
}
```

In this example the Icinga server is running on the same Host like the web and the director.


#### icinga::web::vspheredb

The following example sets up the `vspheredb` Icinga Web 2 module and the required database. At this time only MySQL/MariaDB is support by the Icinga team, so this class also supports only `mysql`.

```puppet
class { 'icinga::web::vspheredb':
  db_type         => 'mysql',
  db_host         => 'localhost',
  db_pass         => Sensitive('vspheredb'),
  manage_database => true,
}
```

#### icinga::web::reporting

The class supports:

* [puppet] >= 7.9.0 < 9.0

And required in addition to `icinga::web::icingadb` or `icinga::web::monitoring`:

* [puppetlabs/mysql] >= 10.9.0 < 17.0.0
* [puppetlabs/postgresql] >= 7.0.0 < 11.0.0
* [icinga/icingaweb2] >= 3.7.0 < 6.0.0

An example to setup reporting and the required database:

```puppet
class { 'icinga::web::reporting':
  db_type         => 'pqsql',
  db_host         => 'localhost',
  db_pass         => Sensitive('reporting'),
  manage_database => true,
}
```

If icinga::web::monitoring is declared before, the required module idoreports for IDO is declared automatically.


## Reference

See [REFERENCE.md](https://github.com/voxpupuli/puppet-icinga/blob/main/REFERENCE.md)

## Transfer Notice

This plugin was originally authored by [Icinga](http://www.icinga.com).
The maintainer preferred that Vox Pupuli take ownership of the module for future improvement and maintenance.
Existing pull requests and issues were transferred over, please fork and continue to contribute here instead of Icinga.

Previously: https://github.com/icinga/puppet-icinga
