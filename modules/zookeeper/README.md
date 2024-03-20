# puppet-zookeeper

[![Puppet
Forge](http://img.shields.io/puppetforge/v/deric/zookeeper.svg)](https://forge.puppetlabs.com/deric/zookeeper) [![Static & Spec Tests](https://github.com/deric/puppet-zookeeper/actions/workflows/spec.yml/badge.svg)](https://github.com/deric/puppet-zookeeper/actions/workflows/spec.yml) [![Puppet Forge
Downloads](http://img.shields.io/puppetforge/dt/deric/zookeeper.svg)](https://forge.puppetlabs.com/deric/zookeeper/scores)

A puppet receipt for [Apache Zookeeper](http://zookeeper.apache.org/). ZooKeeper is a high-performance coordination service for maintaining configuration information, naming, providing distributed synchronization, and providing group services.

## Requirements

  * Puppet
  * Binary or ZooKeeper source code archive

## Basic Usage:

```puppet
class { 'zookeeper': }
```

## Cluster setup

When running ZooKeeper in the distributed mode each node must have unique ID (`1-255`). The easiest way how to setup multiple ZooKeepers, is by using Hiera.

`hiera/host/zk1.example.com.yaml`:
```yaml
zookeeper::id: '1'
```
`hiera/host/zk2.example.com.yaml`:
```yaml
zookeeper::id: '2'
```
`hiera/host/zk3.example.com.yaml`:
```yaml
zookeeper::id: '3'
```
A ZooKeeper quorum should consist of odd number of nodes (usually `3` or `5`).
For defining a quorum it is enough to list all IP addresses of all its members.

```puppet
class { 'zookeeper':
  servers => {
    1 => '192.168.1.1',
    2 => '192.168.1.2',
    3 => '192.168.1.3',
  },
}
```
In case that an array is passed as `servers`, first ZooKeeper will be assigned `ID = 1`. This would produce following configuration:
```
server.1=192.168.1.1:2888:3888
server.2=192.168.1.2:2888:3888
server.3=192.168.1.3:2888:3888
```
where first port is `election_port` and second one `leader_port`. Both ports could be customized for each ZooKeeper instance.

```puppet
class { 'zookeeper':
  election_port => 2889,
  leader_port   => 3889,
  servers       => {
    1 => '192.168.1.1',
    2 => '192.168.1.2',
    3 => '192.168.1.3',
  }
}
```

### Observers

[Observers](http://zookeeper.apache.org/doc/r3.3.0/zookeeperObservers.html) were introduced in ZooKeeper 3.3.0. To enable this feature simply state which of ZooKeeper servers are observing:

```puppet
class { 'zookeeper':
  servers   => ['192.168.1.1', '192.168.1.2', '192.168.1.3', '192.168.1.4', '192.168.1.5'],
  observers => ['192.168.1.4', '192.168.1.5']
}
```
**Note**: Currently observer server needs to be listed between standard servers (this behavior might change in feature).

### Set binding interface

By default ZooKeeper should bind to all interfaces. When you specify `client_ip` only single interface
will be used. If `$::ipaddress` is not your public IP (e.g. you are using Docker) make sure to setup correct IP:

```puppet
class { 'zookeeper':
  client_ip => $::ipaddress_eth0
}
```

or in Hiera:

```yaml
zookeeper::client_ip: "%{::ipaddress_eth0}"
```

This is a workaround for a a [Facter issue](https://tickets.puppetlabs.com/browse/FACT-380).

### ZooKeeper service

Use `service_provider` to override Puppet detection for starting service.

```puppet
class { 'zookeeper':
  service_provider    => 'init',
  manage_service_file => false,
}
```

Some reasonable values are:

  * `init`
  * `systemd`
  * `runit`
  * `exhibitor` - zookeeper process and config will be managed by exhibitor (https://github.com/soabase/exhibitor). Exhibitor is not managed by this module.
  * `none` - service won't be installed

Parameter `manage_service_file` controls whether service definition should be managed by Puppet (default: `false`). Currently supported for `systemd` and `init`.


### Systemd Unit 'After' and 'Want' control
By default the module will create the following Unit section in /etc/systemd/system/multi-user.target.wants/zookeeper.service
````
[Unit]
Description=Apache ZooKeeper
After=network.target
````

Both After and Want (omitted when using the module defaults) can be controled using this module.

E.g on CentOS 7 those might have to be configured for 'netwrok-online.target' using the following syntax:

```puppet
class { 'zookeeper':
   systemd_unit_after => 'network-online.target',
   systemd_unit_want => 'network-online.target',
}
```

Which will modify the Unit section to look like:

````
[Unit]
Description=Apache ZooKeeper
Want=network-online.target
After=network-online.target
````

##  Parameters

   - `id` - cluster-unique zookeeper's instance id (1-255)
   - `datastore`
   - `datalogstore` - Defining `dataLogDir` allows ZooKeeper transaction logs to be stored in a different location, might improve I/O performance (e.g. if path is mounted on dedicated disk)
   - `log_dir`
   - `purge_interval` - automatically will delete ZooKeeper logs (available since ZooKeeper 3.4.0)
   - `snap_retain_count` - number of snapshots that will be kept after purging (since ZooKeeper 3.4.0)
   - `min_session_timeout` - the minimum session timeout in milliseconds that the server will allow the client to negotiate. Defaults to 2 times the **tickTime** (since ZooKeeper 3.3.0)
   - `max_session_timeout` - the maximum session timeout in milliseconds that the server will allow the client to negotiate. Defaults to 20 times the **tickTime** (since ZooKeeper 3.3.0)
   - `global_outstanding_limit` - ZooKeeper will throttle clients so that there is no more than `global_outstanding_limit` outstanding requests in the system.
   - `manage_service` (default: `true`) whether Puppet should ensure running service
   - `manage_service_file` when enabled on RHEL 7.0 a systemd config will be managed
   - `ensure_account` controls whether `zookeeper` user and group will be ensured (set to `false` to disable this feature)
   - `install_method` controls whether ZooKeeper is installed from binary (`package`) or source (`archive`) packages
   - `archive_version` allows to specify an arbitrary version of ZooKeeper when using source packages
   - `archive_install_dir` controls the installation directory when using source packages (defaults to `/opt`)
   - `archive_symlink` controls the name of a version-independent symlink when using source packages
   - `archive_dl_url` allows to change the download URL for source packages (defaults to apache.org)
   - `systemd_path` where to put `systemd` service files (applies only if `manage_service_file` and `service_provider == 'systemd'`)
   - `restart_on_change` whether ZooKeeper service should be restarted on configuration files change (default: `true`)
   - `remove_host_principal` whether to remove host from Kerberos principal (default: `false`)
   - `remove_realm_principal` whether to remove relam from Kerberos principal (default: `false`)
   - `whitelist_4lw` Fine grained control over the set of commands ZooKeeper can execute (an array e.g. `whitelist_4lw = ['*']`)

and many others, see the `params.pp` file for more details.

If your distribution has multiple packages for ZooKeeper, you can provide all package names
as an array.

```puppet
class { 'zookeeper':
  packages => ['zookeeper', 'zookeeper-java']
}
```
## Logging

ZooKeeper uses log4j, following variables can be configured:

```puppet
class { 'zookeeper':
  console_threshold     => 'INFO',
  rollingfile_threshold => 'INFO',
  tracefile_threshold   => 'TRACE',
  maxfilesize           => '256MB',
  maxbackupindex        => 20,
}
```
Threshold supported values are: `ALL`, `DEBUG`, `ERROR`, `FATAL`, `INFO`, `OFF`, `TRACE` and `WARN`.

[Maxfilesize](https://logging.apache.org/log4j/1.2/apidocs/org/apache/log4j/RollingFileAppender.html#maxFileSize)

[MaxBackupIndex](https://logging.apache.org/log4j/1.2/apidocs/org/apache/log4j/RollingFileAppender.html#maxBackupIndex)

By default console, rolling file and trace logging can be configured. Additional log appenders (vulgo log methods) can be configured
by adding a hash `extra_appenders`. The following sets up syslog logging and points the root logger towards syslog (note that you must
have syslog listening on port 514/udp for this to work):

```puppet
class { 'zookeeper':
  log4j_prop      => 'INFO,SYSLOG',
  extra_appenders => {
    'Syslog' => {
      'class'                    => 'org.apache.log4j.net.SyslogAppender',
      'layout'                   => 'org.apache.log4j.PatternLayout',
      'layout.conversionPattern' => "${hostname} zookeeper[id:%X{myid}] - %-5p [%t:%C{1}@%L][%x] - %m%n",
      'syslogHost'               => 'localhost',
      'facility'                 => 'user',
    },
  },
}
```


## Hiera Support

All parameters could be defined in hiera files, e.g. `common.yaml`, `Debian.yaml` or `zookeeper.yaml`:

```yaml
zookeeper::id: 1
zookeeper::client_port: 2181
zookeeper::datastore: '/var/lib/zookeeper'
zookeeper::datalogstore: '/disk2/zookeeper'
```

### Custom RPM repository

Optionally you can specify a custom repository, using a hash configuration.

```puppet
class { 'zookeeper':
  repo       =>  {
    name      => 'myrepo',
    url       => 'http://custom.url',
    descr     => 'description'
    sslverify => 1,
    gpgcheck  => true,
  }
}
```

## Source package

Source packages provide the ability to install arbitrary versions of ZooKeeper on any platform. Note that you'll likely have to use the `manage_service_file` in order to be able to control the ZooKeeper service (because source packages do not install service files).

```puppet
class { 'zookeeper':
  install_method  => 'archive',
  archive_version => '3.4.8',
}
```

Optionally you can specify a `proxy_server`:

```puppet
class { 'zookeeper':
  install_method  => 'archive',
  archive_version => '3.4.8',
  proxy_server    => 'http://10.0.0.1:8080'
}
```

## Java installation

Default: `false`

By changing these two parameters you can ensure, that given Java package will be installed before ZooKeeper packages.

```puppet
class { 'zookeeper':
  install_java => true,
  java_package => 'openjdk-7-jre-headless'
}
```

## Install

### Librarian (recommended)

For [puppet-librarian](https://github.com/rodjek/librarian-puppet) just add to `Puppetfile`

from Forge:
```ruby
mod 'deric-zookeeper'
```

latest (development) version from GitHub
```ruby
mod 'deric-zookeeper', git: 'git://github.com/deric/puppet-zookeeper.git'
```

### submodules

If you are versioning your puppet conf with git just add it as submodule, from your repository root:

    git submodule add git://github.com/deric/puppet-zookeeper.git modules/zookeeper

## Dependencies

  * stdlib `> 2.3.3` - function `ensure_resources` is required
  * puppet-archive `> 0.4.4` - provides capabilities to use archives instead of binary packages


## Acceptance testing

Fastest way is to run tests on prepared Docker images:
```
BEAKER_set=debian9-6.3 bundle exec rake acceptance
```
For examining system state set Beaker's ENV variable `BEAKER_destroy=no`:

```
BEAKER_destroy=no BEAKER_set=default bundle exec rake acceptance
```
and after finishing tests connect to container:
```
docker exec -it adoring_shirley bash
```

When host machine is NOT provisioned (puppet installed, etc.):
```
PUPPET_install=yes BEAKER_set=debian-8 bundle exec rake acceptance
```

Run on specific OS (see `spec/acceptance/nodesets`), to see available sets:
```
rake beaker:sets
```

## Supported platforms

  * Debian/Ubuntu
  * RedHat/CentOS/Fedora/Rocky

### Tested on:

  * Debian (8, 9, 10)
  * Ubuntu (16.04, 18.04)
  * RHEL (6, 7)
  * CentOS (6, 7)
  * SLES (12)
