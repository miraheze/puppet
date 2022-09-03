# icinga

![Icinga Logo](https://www.icinga.com/wp-content/uploads/2014/06/icinga_logo.png)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with icinga](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with icinga](#beginning-with-icinga)
3. [Usage - Configuration options and additional functionality](#usage)
    * [Enable and disable repositories](#enable-and-disable-repositories)
    * [Installing from non upstream repositories](#Installing from Non-Upstream Repositories)
4. [Reference](#reference)
5. [Release notes](#release-notes)


## Description

This module provides several non private helper classes for the official Icinga modules:

* [icinga/icinga2]
* [icinga/icingaweb2]
* [icinga/icingadb]

### Changes in v2.7.0

* The Class icinga::web now uses event as MPM instead of worker.
* Class icinga::repos got a new parameter 'manage_powertools' to manage the PowerTools on CentOS Stream, Rocky and AlmaLinux.


### Changes in v2.0.0

* Earlier the parameter `manage_*` enables or disables a repository but it was still managed. Now the management is enabled or disabled, see [Enable or disable repositories](#enable-and-disable-repositories). 


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

* [puppet] >= 5.5 < 8.0

And requiers:

* [puppetlabs/stdlib] >= 5.1.0 < 9.0.0
* [puppetlabs/apt] >= 6.0.0
* [puppet/zypprepo] >= 2.2.1
* [puppetlabs/yumrepo_core] >= 1.0.0
    * If Puppet 6 or 7 is used

By default the upstream Icinga repository for stable release are involved.
```
include ::icinga::repos
```
To setup the testing repository for release candidates use instead:
```
class { '::icinga::repos':
  manage_stable  => false,
  manage_testing => true,
}
```
Or the nightly builds:
```
class { '::icinga::repos':
  manage_stable  => false,
  manage_nightly => true,
}
```

Other possible needed repositories like EPEL on RHEL or the Backports on Debian can also be involved:
```
class { '::icinga::repos':
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
* epel (only on RHEL Enterprise platforms)
* netways-plugins
* netways-extras

An example for Yum or Zypper based platforms to change from stable to testing repo: 
```
---
icinga::repos::manage_testing: true
icinga::repos:
  icinga-stable-release:
    enabled: 0
```

Or on Apt based platforms:
```
---
icinga::repos::manage_testing: true
icinga::repos:
  icinga-stable-release:
    ensure: absent
```


#### Installing from Non-Upstream Repositories

To change to a non upstream repository, e.g. a local mirror, the repos can be customized via hiera. The module does a deep merge lookup for a hash named `icinga::repos`. Allowed keys are:

* icinga-stable-release
* icinga-testing-builds
* icinga-snapshot-builds
* epel (only on RHEL Enterprise platforms)
* netways-plugins
* netways-extras

An example to configure a local mirror of the stable release:
```
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

```
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

* [puppet] >= 5.5 < 8.0

And requiers:

* [icinga/icinga2] >= 2.0.0 < 4.0.0

Setting up a Icinga Server with a CA and to store configuration:

```
class { '::icinga::server':
  ca            => true,
  ticket_salt   => 'supersecret',
  config_server => true,
  workers       => { 'dmz' => { 'endpoints' => { 'worker.example.org' => { 'host' => '172.16.2.11' }}, }},
  global_zones  => [ 'global-templates', 'linux-commands', 'windows-commands' ],
}
```

Addtition a connection to a worker is configured. By default the zone for the server is named `main`. When `config_server` is enabled directories are managed for all zones, including the worker and global zones.

IMPORTANT: A alpha numeric String has to be set to `ticket_salt` in Hiera to protect the CA! An alternative is to set `icinga::ticket_salt` in a hiera common section for all agents, workers and servers.

The associated worker could look like this:

```
class { '::icinga::worker':
  ca_server        => '172.16.1.11',
  zone             => 'dmz',
  parent_endpoints => { 'server.example.org' => { 'host' => '172.16.1.11', }, },
  global_zones     => [ 'global-templates', 'linux-commands', 'windows-commands' ],
}
```

If the worker doesn't have a certificate, it sends a certificate request to the CA on the host `ca_server`. The default parent zone is `main`. Thus, only the associated endpoint has to be defined.

If `icinga::ticket_salt` is also set in Hiera for the worker, he's automatically sent a certificate. Otherwise the request will be saved on the CA server and must be signed manually.

Both, server and workers, can operated with a parnter in the same zone to share load. The endpoint of the respective partner is specified as an Icinga object in `colocation_endpoints`.

```
colocation_endpoints => { 'server2.example.org' => { 'host' => '172.16.1.12', } },
``` 

Of course, the second endpoint must also be specified in the respective `parent_endpoints` of the worker or agent.

An agent is very similar to a worker, only it has no parameter `colocation_endpoints`:

```
class { '::icinga::agent':
  ca_server        => '172.16.1.11',
  parent_endpoints => { 'worker.example.org' => { 'host' => '172.16.2.11', }, } },
  global_zones     => [ 'linux-commands' ],
}
```

NOTICE: To switch off the package installation via chocolatey on windows, `icinga2::manage_packgaes` must be set to `false` for the corresponding hosts in Hiera. That works only on Windows, on Linux package installation is always used.


#### icinga::ido

The class supports:

* [puppet] >= 5.5 < 8.0

Ands requires:

* [puppetlabs/mysql] >= 6.0.0
* [puppetlabs/postgresql] >= 7.0.0
* [icinga/icinga2] >= 2.0.0 < 4.0.0

To activate and configure the IDO feature (usally on a server) do:

```
class { '::icinga::ido':
  db_type         => 'pgsql',
  db_host         => 'localhost',
  db_pass         => 'icinga2',
  manage_database => true,
}
```

Setting `manage_database` to `true` also setups a database as specified in `db_type` including database for the IDO. Supported are `pgsql` for PostgreSQL und `maysql` for MariaDB. By default the database name is set to `icinga2` and the user to `icinga2`.

### icinga::web

The class supports:

* [puppet] >= 5.5 < 8.0

And requires:

* [puppetlabs/mysql] >= 6.0.0
* [puppetlabs/postgresql] >= 7.0.0
* [puppetlabs/apache] >= 3.0.0
* [puppet/php] >= 6.0.0
* [icinga/icinga2] >= 2.0.0
* [icinga/icingaweb2] >= 2.0.0

A Icinga Web 2 with an Apache and PHP-FPM can be managed as follows:

```
class { '::icinga::web':
  backend_db_type => $icinga::ido::db_type,
  backend_db_host => $icinga::ido::db_host,
  backend_db_pass => $icinga::ido::db_pass,
  db_type         => 'pgsql',
  db_host         => 'localhost',
  db_pass         => 'supersecret',
  manage_database => true,
  api_pass        => $icinga::server::web_api_pass,
}
```

If the Icinga Web 2 is operated on the same host as the IDO, the required user credentials can be accessed, otherwise they must be specified explicitly. With `manage_database` set to `true`, a database of the specified type is also installed here. It is used to save user settings for the users of the Icinga Web 2.

IMPORTANT: If you plan tu use icingacli as plugin, e.g. director health checks, businessprocess checks or vspheredb checks, set the parameter `run_web => true` for `icinga::server` on the same host `icinga::web` is declared. That put the Icinga user to the group `icingaweb2` and restart the icinga2 process if necessary.


#### icinga::web::director

Install and manage the famous Icinga Director and the required database. A graphical addon to manage your monitoring environment, the hosts, services, notifications etc.

Here an example with an PostgreSQL database on the same host:

```
class { '::icinga::web::director':
  db_type         => 'pgsql',
  db_host         => 'localhost',
  db_pass         => 'supersecret',
  manage_database => true,
  endpoint        => $::fqdn,
  api_host        => 'localhost',
  api_pass        => $icinga::server::director_api_pass,
}
```

In this example the Icinga server is running on the same Host like the web and the director.


#### icinga::web::vspheredb

The class supports:

* [puppet] >= 5.5 < 8.0

And required in addition to `icinga::web`:

* [icinga/icingaweb2] >= 3.2.0

The following example sets up the `vspheredb` Icinga Web 2 module and teh required database. At this time only MySQL/MariaDB is support by the Icinga team, so this class also supports only `mysql`.

```
class { '::icinga::web::vspheredb':
  db_type         => 'mysql',
  db_host         => 'localhost',
  db_pass         => 'vspheredb',
  manage_database => true,
}
```

## Reference

See [REFERENCE.md](https://github.com/Icinga/puppet-icinga/blob/master/REFERENCE.md)

## Release Notes

This code is a very early release and may still be subject to significant changes.
