# mattermost

[![Puppet Forge - downloads](https://img.shields.io/puppetforge/dt/liger1978/mattermost.svg)](https://forge.puppetlabs.com/liger1978/mattermost)
[![Puppet Forge - scores](https://img.shields.io/puppetforge/f/liger1978/mattermost.svg)](https://forge.puppetlabs.com/liger1978/mattermost)
[![GitLab - build status](https://gitlab.com/harbottle/puppet-mattermost/badges/master/pipeline.svg)](https://gitlab.com/harbottle/puppet-mattermost/pipelines)

#### Table of Contents

1. [Overview](#overview)
2. [Module Changes](#module-changes)
3. [Module Description - What the module does and why it is useful](#module-description)
4. [Setup - The basics of getting started with mattermost](#setup)
    * [What mattermost affects](#what-mattermost-affects)
    * [Beginning with mattermost](#beginning-with-mattermost)
5. [Usage - Configuration options and additional functionality](#usage)
    * [Upgrading Mattermost](#upgrading-mattermost)
      - [Security Updates](#security-updates)
6. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
    * [Public classes](#public-classes)
    * [Private classes](#private-classes)
    * [Parameters](#parameters)
    * [Public defined types](#public-defined-types)
7. [Limitations - OS compatibility, etc.](#limitations)
8. [Development - Guide for contributing to the module](#development)

## Overview

This module installs and configures [Mattermost](http://www.mattermost.org/), to
provide secure, private cloud messaging for teams and enterprises. More
information is available at:
[https://about.mattermost.com](https://about.mattermost.com).

The name for this deployment solution in the context of the
[Mattermost branding guidelines](https://www.mattermost.org/brand-guidelines/)
is `Puppet module for Mattermost by Richard Grainger`.

Following automated deployment, the following steps are required to make your
system production-ready:

 - [Configure SSL for Mattermost](https://about.mattermost.com/ssl-configuration/)
 - [Configure SMTP email for Mattermost](https://about.mattermost.com/smtp-configuration/)

Please see [https://docs.mattermost.com](https://docs.mattermost.com) for the
official Mattermost documentation.

## Module Changes

From module version **1.7.0**, the default value of `conf` (the default
Mattermost configuration file location) has changed to `/etc/mattermost.conf`.
This is to allow configuration changes made using the web GUI to be preserved
during Mattermost application upgrades.

## Module Description

The Mattermost module does the following:

 - Installs the Mattermost server from a release archive on the web, an
   alternative download location within your firewall or using a package.
 - Installs and configures a daemon (service) for Mattermost in the format
   native to your operating system.
 - Configures Mattermost according to settings you provide.

## Setup

### What mattermost affects

When using a release archive:

* Downloads and installs Mattermost server (defaults to
  `/opt/mattermost-${version}`).
* Creates a friendly symbolic link to the installation directory (defaults to
  `/opt/mattermost`).
* Creates a configuration file (defaults to `/etc/mattermost.json`) based on
  the vendor-provided configuration file and adds user-supplied options.
* Create an environment variable configuration file (defaults to
  `/etc/sysconfig/mattermost` or `/etc/default/mattermost` depending on
  platform) and add user-supplied options.
* Creates and manages a Mattermost daemon (service) using your operating
  system's native service provider.

When using a package:

* Installs the package.
* Add user-supplied options to the configuration files.
* Manages the service .

### Beginning with mattermost

If you have a suitable database installed for Mattermost server to use as a
backend, this is the minimum you need to get Mattermost server working by
configuring environment variables that will be used by the installed Mattermost
service:

Using Puppet only:

```puppet
class { 'mattermost':
  override_env_options => {
    'MM_SQLSETTINGS_DRIVERNAME' => 'postgres',
    'MM_SQLSETTINGS_DATASOURCE' => "postgres://db_user:db_pass@db_host:db_port/mattermost?sslmode=disable&connect_timeout=10",
  },
}
```

Using Puppet and Hiera:

```puppet
include mattermost
```

```yaml
mattermost::override_env_options:
  MM_SQLSETTINGS_DRIVERNAME: postgres
  MM_SQLSETTINGS_DATASOURCE: postgres://db_user:db_pass@db_host:db_port/mattermost?sslmode=disable&connect_timeout=10
```

Alternatively, the minimum configuration can be supplied by configuring Mattermost's json config file:

Using Puppet only:

```puppet
class { 'mattermost':
  override_options => {
    'SqlSettings' => {
      'DriverName' => 'postgres',
      'DataSource' => "postgres://db_user:db_pass@db_host:db_port/mattermost?sslmode=disable&connect_timeout=10",
    },
  },
}
```

Using Puppet and Hiera:

```puppet
include mattermost
```

```yaml
mattermost::override_options:
  SqlSettings:
    DriverName: postgres
    DataSource: postgres://db_user:db_pass@db_host:db_port/mattermost?sslmode=disable&connect_timeout=10
```

Any of these options will install a Mattermost server listening on the default TCP port
(currently 8065).

The module's default behaviour is to download and install Mattermost using a
`.tar.gz` archive. The module can instead install Mattermost using a package.
Here is an example using the `mattermost-server` package in the
[harbottle-main](https://harbottle.gitlab.io/harbottle-main/7/x86_64/) RPM repo
for CentOS 7:

```puppet
yumrepo { 'harbottle-main':
  baseurl  => 'https://copr-be.cloud.fedoraproject.org/results/harbottle/main/epel-7-$basearch/',
  descr    => 'harbottle-main',
  gpgcheck => true,
  gpgkey   => 'https://copr-be.cloud.fedoraproject.org/results/harbottle/main/pubkey.gpg',
}
-> class { 'mattermost':
  install_from_pkg => true,
  version          => latest,
  conf             => '/etc/mattermost/config.json',
  override_options => {
    'SqlSettings'  => {
      'DriverName' => 'postgres',
      'DataSource' => "postgres://db_user:db_pass@db_host:db_port/mattermost?sslmode=disable&connect_timeout=10",
    },
  },
}
```

Here is an example of Mattermost using PostgreSQL as a database and NGINX as a
reverse proxy, all running on the same system (requires
[puppetlabs/postgresql](https://forge.puppetlabs.com/puppetlabs/postgresql) and
[puppet/nginx](https://forge.puppet.com/puppet/nginx)):

```puppet
class { 'postgresql::globals':
  manage_package_repo => true,
  version             => '9.4',
}
class { 'postgresql::server':
  ipv4acls => ['host all all 127.0.0.1/32 md5'],
}
postgresql::server::db { 'mattermost':
   user     => 'mattermost',
   password => postgresql_password('mattermost', 'mattermost'),
}
postgresql::server::database_grant { 'mattermost':
  privilege => 'ALL',
  db        => 'mattermost',
  role      => 'mattermost',
}
-> class { 'mattermost':
  override_options => {
    'SqlSettings' => {
      'DriverName' => 'postgres',
      'DataSource' => "postgres://mattermost:mattermost@127.0.0.1:5432/mattermost?sslmode=disable&connect_timeout=10",
    },
  },
}
class { 'nginx': }
nginx::resource::upstream { 'mattermost':
  members => [ 'localhost:8065' ],
}
nginx::resource::server { 'mattermost':
  server_name         => [ 'myserver.mydomain' ],
  proxy               => 'http://mattermost',
  location_cfg_append => {
    'proxy_http_version'          => '1.1',
    'proxy_set_header Upgrade'    => '$http_upgrade',
    'proxy_set_header Connection' => '"upgrade"',
  },
}
```

With the above code, you should be able to access the Mattermost application at
`http://myserver.mydomain` (or whatever resolvable DNS domain you chose) via
the NGINX reverse proxy listening on port 80.

## Usage

Mattermost [config settings](https://docs.mattermost.com/administration/config-settings.html)
can be set using environment variables or a json file.

Configuration options supplied using environment variables takes precedence over options
supplied using the json file and they disable modification using the Service Console.

You must decide which method to use.

Use `override_options` to change Mattermost's default settings by modifying the json file:

```puppet
class { 'mattermost':
  override_options => {
    'ServiceSettings' => {
      'ListenAddress' => ":80",
    },
    'TeamSettings' => {
      'SiteName' => 'BigCorp Collaboration',
    },
    'SqlSettings' => {
      'DriverName' => 'postgres',
      'DataSource' => "postgres://mattermost:mattermost@127.0.0.1:5432/mattermost?sslmode=disable&connect_timeout=10",
    },
    'FileSettings' => {
      'Directory' => '/var/mattermost',
    },
  }
}
```

Use `override_env_options` to change Mattermost's default settings by modifying environment variables:

```puppet
class { 'mattermost':
  override_env_options => {
    'MM_SERVICESETTINGS_LISTENADDRESS' => ":80",
    'MM_TEAMSETTINGS_SITENAME'         => 'BigCorp Collaboration',
    'MM_SQLSETTINGS_DRIVERNAME'        => 'postgres',
    'MM_SQLSETTINGS_DATASOURCE'        => "postgres://mattermost:mattermost@127.0.0.1:5432/mattermost?sslmode=disable&connect_timeout=10",
    'MM_FILESETTINGS_DIRECTORY'        => '/var/mattermost',
    },
  }
}
```

Store file data, such as file uploads, in a separate directory (recommended), json file method:

```puppet
class { 'mattermost':
  override_options => {
    'FileSettings' => {
      'Directory' => '/var/mattermost',
    },
  },
}
```

Store file data, such as file uploads, in a separate directory (recommended), environment variables method:

```puppet
class { 'mattermost':
  override_env_options => {
    'MM_FILESETTINGS_DIRECTORY' => '/var/mattermost',
  },
}
```

Install a specific version:

```puppet
class { 'mattermost':
  version => '5.21.0',
}
```

Install Enterprise edition:

```puppet
class { 'mattermost':
  edition => 'enterprise',
}
```

Install a release candidate:

```puppet
class { 'mattermost':
  version => '5.21.0-rc1',
}
```

Download from an internal server:

```puppet
class { 'mattermost':
  version  => '5.21.0',
  full_url => 'http://intranet.bigcorp.com/packages/mattermost.tar.gz',
}
```

### Upgrading Mattermost

The module can elegantly upgrade your Mattermost installation. To upgrade,
just specify the new version when it has been released, for example:

```puppet
class { 'mattermost':
  version => '5.21.0',
}
```

On the next Puppet run, when using a release archive, the new version will be
downloaded and installed; the friendly symbolic link will be changed to point at
the new installation directory and the service will be refreshed.

When using a package, the new package will be installed and the service will be
refreshed.

**Note 1:**  The Mattermost application supports certain upgrade paths only.
Please see the [upgrade guide](https://docs.mattermost.com/administration/upgrade.html)

**Note 2:** Always
[backup your data](https://docs.mattermost.com/administration/backup.html)
before upgrades.

**Note 3:** For a seamless upgrade you should store your file data outside of
the Mattermost installation directory so that your uploaded files are still
accessible after each upgrade. For example:

```puppet
class { 'mattermost':
  override_env_options => {
    'MM_FILESETTINGS_DIRECTORY' => '/var/mattermost',
  },
}
```

or

```puppet
class { 'mattermost':
  override_options => {
    'FileSettings' => {
      'Directory' => '/var/mattermost',
    },
  },
}
```

#### Security Updates
We highly recommend users subscribe to the
[Mattermost security updates email list](https://mattermost.com/blog/category/security-updates/).
When notified of a security update, the maintainers of this deployment
solution will make an effort to update to the secure version within 10 days.

## Reference

### Public classes

 - `mattermost`: Main class, includes all other classes

### Private classes

 - `mattermost::install`: Installs the Mattermost server from a web archive or
   using a package and optionally installs a daemon (service) for Mattermost in
   the format native to your operating system.
 - `mattermost::config`: Configures Mattermost according to provided settings.
 - `mattermost::service`: Manages the Mattermost daemon.

### Parameters

#### mattermost

##### `install_from_pkg`

The default behaviour is to install from a remote Mattermost server release
archive. Enable this option to instead install from a package. The package
should be available to install from a existing repository. Defaults to `false`.

**Helpful hint:** The author of this module has has created a
[package](https://gitlab.com/harbottle/harbottle-main/blob/master/docs/mattermost-server.md)
suitable for RHEL 7, CentOS 7 and Oracle Linux 7 users.

##### `pkg`

The package name when installing from a package. Defaults to
`mattermost-server`.

##### `base_url`

The base URL to download the Mattermost server release archive. Ignored if
installing from a package. Defaults to `https://releases.mattermost.com`.

##### `edition`

The edition of Mattermost server to install. Ignored if installing from a
package. Defaults to `team`. Valid values are `team` and `enterprise`.

##### `version`

The version of Mattermost server to install. Defaults to `5.21.0`.

##### `file_name`

The filename of the remote Mattermost server release archive. Ignored if
installing from a package. Defaults to
`mattermost-team-${version}-linux-amd64.tar.gz` (for Team edition) or
`mattermost-${version}-linux-amd64.tar.gz` (for Enterprise edition), so with
the default `version`, the default value will be
`mattermost-team-5.21.0-linux-amd64.tar.gz`.

##### `full_url`

The full URL of the Mattermost server release archive. Ignored if installing
from a package. Defaults to `${base_url}/${version}/${filename}`, so with the
default `base_url`, `edition`, `version` and `file_name`, this will be:
`https://releases.mattermost.com/5.21.0/mattermost-team-5.21.0-linux-amd64.tar.gz`.

**Please note:** If you set `full_url` you should also set `version`
to match the version of Mattermost server you are installing.

##### `dir`

The directory to install Mattermost server on your system. Ignored if installing
from a package. Defaults to `/opt/mattermost-${version}`.

##### `symlink`

The path of the friendly symbolic link to the versioned Mattermost installation
directory. Ignored if installing from a package. Defaults to `/opt/mattermost`.

##### `conf`

The path to Mattermost's config file. Defaults to `/etc/mattermost.json`.

##### `env_conf`

The path to Mattermost's environment variable config file. Defaults to
`/etc/sysconfig/mattermost` (Enterprise Linux/SLES) or `/etc/default/mattermost`
(Debian/Ubuntu).

##### `create_user`

Should the module create an unprivileged system account that will be used to run
Mattermost server? Ignored if installing from a package. Defaults to `true`.

##### `create_group`

Should the module create an unprivileged system group that will be used to run
Mattermost server? Ignored if installing from a package. Defaults to `true`.

##### `user`

The name of the unprivileged system account that will be used to run Mattermost
server and will own the config file. Defaults to `mattermost`.

##### `group`

The name of the unprivileged system group that will be used to run Mattermost
serverand will own the config file. Defaults to `mattermost`.

##### `uid`

The uid of the unprivileged system account that will be used to run
Mattermost server. Ignored if installing from a package. Defaults to `1500`.

##### `gid`

The gid of the unprivileged system group that will be used to run
Mattermost server. Ignored if installing from a package. Defaults to `1500`.

##### `override_options`
Mattermost [config settings](https://docs.mattermost.com/administration/config-settings.html)
can be set using environment variables or a json file.

Configuration options supplied using environment variables takes precedence over options
supplied using the json file and disable modification using ther Service Console.

You must decide which method to use.

This is a hash containing overrides to the default settings contained in Mattermost's
[json config file](https://github.com/mattermost/mattermost-server/blob/master/config/default.json).
Defaults to `{}` (empty hash).

**Note 1:** If you decide to configure Mattermost using a json file,
you should at least specify `SqlSettings`, e.g.:

```puppet
class { 'mattermost':
  override_options => {
    'SqlSettings' => {
      'DriverName' => 'postgres',
      'DataSource' => "postgres://db_user:db_pass@db_host:db_port/mattermost?sslmode=disable&connect_timeout=10",
    },
  },
}
```

**Note 2:** To purge existing settings from the configuration file, use the
[`purge_conf`](#purge_conf) parameter.

###### `override_options['FileSettings']['Directory']`

An element of the `override_options` hash that specifies the Mattermost data
directory. Setting this element will result in the directory being created with
the correct permissions if it does not already exist (unless
[`manage_data_dir`](#manage_data_dir) is `false`).

**Note:** [`override_env_options['MM_FILESETTINGS_DIRECTORY']`](#override_env_optionsmm_filesettings_directory)
takes precedence over this element.

An absolute path must be specified. Example:

```puppet
class { 'mattermost':
  override_options => {
    'FileSettings' => {
      'Directory' => '/var/mattermost',
    },
  },
}
```

###### `override_options['LogSettings']['FileLocation']`

An element of the `override_options` hash that specifies the Mattermost log
directory. Setting this element will result in the directory being created with
the correct permissions if it does not already exist (unless
[`manage_log_dir`](#manage_log_dir) is `false`).

**Note:** [`override_env_options['MM_LOGSETTINGS_FILELOCATION']`](#override_env_optionsmm_logsettings_filelocation)
takes precedence over this element.

An absolute path must be specified. Example:

```puppet
class { 'mattermost':
  override_options => {
    'LogSettings' => {
      'FileLocation' => '/var/log/mattermost',
    },
  },
}
```

##### `override_env_options`

Mattermost [config settings](https://docs.mattermost.com/administration/config-settings.html)
can be set using environment variables or a json file.

Configuration options supplied using environment variables takes precedence over options
supplied using the json file and disable modification using ther Service Console.

You must decide which method to use.

This is a hash containing overrides to Mattermost's environment variables that
will be stored in the [`env_conf`](#env_conf) environment variable file.
Defaults to `{}` (empty hash).

**Note 1:** If you decide to configure Mattermost using environment variables,
you should at least specify database settings, e.g.:

```puppet
class { 'mattermost':
  override_env_options => {
    'MM_SQL_SETTINGS_DRIVERNAME' => 'postgres',
    'MM_SQL_SETTINGS_DATASOURCE' => "postgres://db_user:db_pass@db_host:db_port/mattermost?sslmode=disable&connect_timeout=10",
  },
}
```

**Note 2:** To purge existing settings from the environment variable file, use the
[`purge_env_conf`](#purge_env_conf) parameter.

###### `override_env_options['MM_FILESETTINGS_DIRECTORY']`

An element of the `override_env_options` hash that specifies the Mattermost data
directory. Setting this element will result in the directory being created with
the correct permissions if it does not already exist (unless
[`manage_data_dir`](#manage_data_dir) is `false`).

**Note:** This takes precedence over [`override_options['FileSettings']['Directory']`](#override_optionsfilesettingsdirectory)

An absolute path must be specified. Example:

```puppet
class { 'mattermost':
  override_env_options => {
    'MM_FILESETTINGS_DIRECTORY' => '/var/mattermost',
  },
}
```

###### `override_env_options['MM_LOGSETTINGS_FILELOCATION']`

An element of the `override_env_options` hash that specifies the Mattermost log
directory. Setting this element will result in the directory being created with
the correct permissions if it does not already exist (unless
[`manage_log_dir`](#manage_log_dir) is `false`).

**Note:** This takes precedence over [`override_options['LogSettings']['FileLocation']`](#override_optionslogsettingsfilelocation)

An absolute path must be specified. Example:

```puppet
class { 'mattermost':
  override_env_options => {
    'MM_LOGSETTINGS_FILELOCATION' => '/var/log/mattermost',
  },
}
```

##### `purge_conf`

Should the module purge existing settings from Mattermost configuration file?
Defaults to `false`.

##### `purge_env_conf`

Should the module purge existing settings from Mattermost environment variable file?
Defaults to `false`.

##### `manage_data_dir`

Should the module ensure Mattermost's data directory exists and has the correct
permissions? This parameter only applies if
[`override_env_options['MM_FILESETTINGS_DIRECTORY']`](#override_env_optionsmm_filesettings_directory)
or
[`override_options['FileSettings']['Directory']`](#override_optionsfilesettingsdirectory)
is set. Ignored if installing from a package. Defaults to `true`.

##### `manage_log_dir`

Should the module ensure Mattermost's log directory exists and has the correct
permissions? This parameter only applies if
[`override_env_options['MM_LOGSETTINGS_FILELOCATION']`](#override_env_optionsmm_logsettings_filelocation)
or
[`override_options['LogSettings']['FileLocation']`](#override_optionslogsettingsfilelocation)
is set. Ignored if installing from a package. Defaults to `true`.

##### `depend_service`

The local service (i.e. database service) that Mattermost server needs to start
when it is installed on the same server as the database backend. Ignored if
installing from a package.Defaults to `''` (empty string).

##### `install_service`

Should the module install a daemon for Mattermost server appropriate to your
operating system? Ignored if installing from a package. Defaults to `true`.

##### `manage_service`

Should the module manage the installed Mattermost server daemon
(`ensure => 'running'` and `enable => true`)? Defaults to `true`.

##### `service_name`

The service name. Defaults to `mattermost`.

##### `service_template`

`ERB` (Embedded RuBy) template to use for the service definition file. Ignored
if installing from a package. Defaults to a bundled template suitable for the
server's operating system.

##### `service_path`

The target path for the service definition file. Ignored if installing from a
package. Defaults to the standard path for the server's operating system.

##### `service_provider`

The Puppet service provider to use for service management. Defaults to an
appropriate value for the server's operating system.

### Public defined types

#### Defined type: `mattermost_settings`

Defines settings within a JSON-formatted Mattermost configuration file.

**Example:**

```puppet
mattermost_settings{ '/etc/mattermost.json':
  values  => {
    'SqlSettings' => {
      'DriverName' => 'postgres',
      'DataSource' => "postgres://mattermost:mattermost@127.0.0.1:5432/mattermost?sslmode=disable&connect_timeout=10",
    },
    'TeamSettings' => {
      'SiteName' => 'Dev Team',
    },
  },
}
```

`mattermost_settings` parameters:

##### `name`

An arbitrary name for the resource. It will be the default for 'target'.

##### `target`

The path to the mattermost config file to manage. Either this file should
already exist, or the source parameter needs to be specified.

##### `source`

The file from which to load the current settings. If unspecified, it defaults to
the target file.

##### `allow_new_value`

Whether it should be allowed to specify values for non-existing tree portions.
Defaults to `true`.

##### `allow_new_file`

Whether it should be allowed to create a new target file.  Default to `true`.

##### `user`

The user with which to make the changes.

##### `values`

The portions to change and their new values. This should be a hash. The subtree
to change is specified in the form:

```
<key 1>/<key 2>/.../<key n>
```

where `<key x>` admits three variants:
  * the plain contents of the string key, as long as they do not start
    with `:` or `'` and do not contain `/`
  * `'<contents>'`, to represent a string key that contains the characters
    mentioned above. Single quotes must be doubled to have literal value.
  * `:'<contents>'`, likewise, but the value will be a symbol.

## Limitations

This module has been tested with Puppet 3, 4, 5 and 6.

This module has been tested on:

* Red Hat Enterprise Linux 6, 7, 8
* CentOS 6, 7, 8
* Oracle Linux 6, 7, 8
* Scientific Linux 6, 7
* Debian 8, 9, 10
* Ubuntu 14.04, 16.04, 18.04, 19.04
* SLES 12, 15

**Note:** According to the
[Mattermost software requirements documentation](https://docs.mattermost.com/install/requirements.html#software-requirements),
the following platforms are offically supported by Mattermost:
 > Ubuntu 16.04, Ubuntu 18.04, Debian Buster, CentOS 6+, CentOS 7+, RedHat Enterprise Linux 6+, RedHat Enterprise Linux 7+, Oracle Linux 6+, Oracle Linux 7+

## Development

Please send pull requests.  For maintenance and contributor info, see
[the maintainer guide](https://gitlab.com/harbottle/puppet-mattermost/blob/master/MAINTENANCE.md).
