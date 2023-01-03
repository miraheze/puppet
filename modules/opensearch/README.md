# Opensearch Puppet Module
[![Apache-2 License](https://img.shields.io/github/license/voxpupuli/puppet-elasticsearch.svg)](LICENSE)

#### Table of Contents

1. [Module description - What the module does and why it is useful](#module-description)
2. [Setup - The basics of getting started with Opensearch](#setup)
  * [The module manages the following](#the-module-manages-the-following)
  * [Requirements](#requirements)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Advanced features - Extra information on advanced usage](#advanced-features)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
6. [Limitations - OS compatibility, etc.](#limitations)
7. [Development - Guide for contributing to the module](#development)
8. [Support - When you need help with this module](#support)
9. [Transfer Notice](#transfer-notice)

## Module description

This module sets up [Opensearch](https://opensearch.org) instances with additional resource for plugins, templates, and more.

## Setup

### The module manages the following

* Opensearch repository files.
* Opensearch package.
* Opensearch configuration file.
* Opensearch service.
* Opensearch plugins.
* Opensearch snapshot repositories.
* Opensearch templates.
* Opensearch ingest pipelines.
* Opensearch index settings.
* Opensearch users, roles, and certificates.
* Opensearch licenses.
* Opensearch keystores.

### Requirements

* The [stdlib](https://forge.puppetlabs.com/puppetlabs/stdlib) Puppet library.
* [Augeas](http://augeas.net/)
* [puppetlabs-java_ks](https://forge.puppetlabs.com/puppetlabs/java_ks) for certificate management (optional).

We recommend managing your Java installation with the [puppetlabs-java](https://forge.puppetlabs.com/puppetlabs/java) module.

#### Repository management

When using the repository management, the following module dependencies are required:

* Debian/Ubuntu: [Puppetlabs/apt](https://forge.puppetlabs.com/puppetlabs/apt)
* openSUSE/SLES: [puppet/zypprepo](https://forge.puppetlabs.com/puppet/zypprepo)

### Beginning with Opensearch

Declare the top-level `opensearch` class (managing repositories) and set up an instance:

```puppet
include ::java

class { 'opensearch': }
```

## Usage

### Main class

Most top-level parameters in the `opensearch` class are set to reasonable defaults.
The following are some parameters that may be useful to override:

#### Install a specific version

```puppet
class { 'opensearch':
  version => '2.4.1'
}
```

Note: This will only work when using the repository.

#### Automatically restarting the service (default set to false)

By default, the module will not restart Opensearch when the configuration file, package, or plugins change.
This can be overridden globally with the following option:

```puppet
class { 'opensearch':
  restart_on_change => true
}
```

Or controlled with the more granular options: `restart_config_change`, `restart_package_change`, and `restart_plugin_change.`

#### Automatic upgrades (default set to false)

```puppet
class { 'opensearch':
  autoupgrade => true
}
```

#### Removal/Decommissioning

```puppet
class { 'opensearch':
  ensure => 'absent'
}
```

#### Install everything but disable service(s) afterwards

```puppet
class { 'opensearch':
  status => 'disabled'
}
```

#### API Settings

Some resources, such as `opensearch::template`, require communicating with the Opensearch REST API.
By default, these API settings are set to:

```puppet
class { 'opensearch':
  api_protocol            => 'http',
  api_host                => 'localhost',
  api_port                => 9200,
  api_timeout             => 10,
  api_basic_auth_username => undef,
  api_basic_auth_password => undef,
  api_ca_file             => undef,
  api_ca_path             => undef,
  validate_tls            => true,
}
```

Each of these can be set at the top-level `opensearch` class and inherited for each resource or overridden on a per-resource basis.

#### Dynamically Created Resources

This module supports managing all of its defined types through top-level parameters to better support Hiera and Puppet Enterprise.
For example, to manage an index template directly from the `opensearch` class:

```puppet
class { 'opensearch':
  templates => {
    'logstash' => {
      'content' => {
        'template' => 'logstash-*',
        'settings' => {
          'number_of_replicas' => 0
        }
      }
    }
  }
}
```
### Plugins

This module can help manage [a variety of plugins](https://opensearch.org/docs/latest/install-and-configure/install-opensearch/plugins/).
Note that `module_dir` is where the plugin will install itself to and must match that published by the plugin author; it is not where you would like to install it yourself.

#### From a custom url

```puppet
opensearch::plugin { 'jetty':
  url => 'https://oss-es-plugins.s3.amazonaws.com/opensearch-jetty/opensearch-jetty-1.2.1.zip'
}
```

#### Using a proxy

You can also use a proxy if required by setting the `proxy_host` and `proxy_port` options:
```puppet
opensearch::plugin { 'lmenezes/opensearch-kopf',
  proxy_host => 'proxy.host.com',
  proxy_port => 3128
}
```

Proxies that require usernames and passwords are similarly supported with the `proxy_username` and `proxy_password` parameters.

#### Upgrading plugins

When you specify a certain plugin version, you can upgrade that plugin by specifying the new version.

```puppet
opensearch::plugin { 'opensearch/opensearch-cloud-aws/2.1.1': }
```

And to upgrade, you would simply change it to

```puppet
opensearch::plugin { 'opensearch/opensearch-cloud-aws/2.4.1': }
```

Please note that this does not work when you specify 'latest' as a version number.

### Scripts

Installs [scripts](https://opensearch.org/docs/latest/api-reference/script-apis/index/) to be used by Opensearch.
These scripts are shared across all defined instances on the same host.

```puppet
opensearch::script { 'myscript':
  ensure => 'present',
  source => 'puppet:///path/to/my/script.groovy'
}
```

Script directories can also be recursively managed for large collections of scripts:

```puppet
opensearch::script { 'myscripts_dir':
  ensure  => 'directory,
  source  => 'puppet:///path/to/myscripts_dir'
  recurse => 'remote',
}
```

### Templates

By default templates use the top-level `opensearch::api_*` settings to communicate with Opensearch.
The following is an example of how to override these settings:

```puppet
opensearch::template { 'templatename':
  api_protocol            => 'https',
  api_host                => $::ipaddress,
  api_port                => 9201,
  api_timeout             => 60,
  api_basic_auth_username => 'admin',
  api_basic_auth_password => 'adminpassword',
  api_ca_file             => '/etc/ssl/certs',
  api_ca_path             => '/etc/pki/certs',
  validate_tls            => false,
  source                  => 'puppet:///path/to/template.json',
}
```

#### Add a new template using a file

This will install and/or replace the template in Opensearch:

```puppet
opensearch::template { 'templatename':
  source => 'puppet:///path/to/template.json',
}
```

#### Add a new template using content

This will install and/or replace the template in Opensearch:

```puppet
opensearch::template { 'templatename':
  content => {
    'template' => "*",
    'settings' => {
      'number_of_replicas' => 0
    }
  }
}
```

Plain JSON strings are also supported.

```puppet
opensearch::template { 'templatename':
  content => '{"template":"*","settings":{"number_of_replicas":0}}'
}
```

#### Delete a template

```puppet
opensearch::template { 'templatename':
  ensure => 'absent'
}
```

### Ingestion Pipelines

Pipelines behave similar to templates in that their contents can be controlled
over the Opensearch REST API with a custom Puppet resource.
API parameters follow the same rules as templates (those settings can either be
controlled at the top-level in the `opensearch` class or set per-resource).

#### Adding a new pipeline

This will install and/or replace an ingestion pipeline in Opensearch
(ingestion settings are compared against the present configuration):

```puppet
opensearch::pipeline { 'addfoo':
  content => {
    'description' => 'Add the foo field',
    'processors' => [{
      'set' => {
        'field' => 'foo',
        'value' => 'bar'
      }
    }]
  }
}
```

#### Delete a pipeline

```puppet
opensearch::pipeline { 'addfoo':
  ensure => 'absent'
}
```


### Index Settings

This module includes basic support for ensuring an index is present or absent
with optional index settings.
API access settings follow the pattern previously mentioned for templates.

#### Creating an index

At the time of this writing, only index settings are supported.
Note that some settings (such as `number_of_shards`) can only be set at index
creation time.

```puppet
opensearch::index { 'foo':
  settings => {
    'index' => {
      'number_of_replicas' => 0
    }
  }
}
```

#### Delete an index

```puppet
opensearch::index { 'foo':
  ensure => 'absent'
}
```

### Snapshot Repositories

By default snapshot_repositories use the top-level `opensearch::api_*` settings to communicate with Opensearch.
The following is an example of how to override these settings:

```puppet
opensearch::snapshot_repository { 'backups':
  api_protocol            => 'https',
  api_host                => $::ipaddress,
  api_port                => 9201,
  api_timeout             => 60,
  api_basic_auth_username => 'admin',
  api_basic_auth_password => 'adminpassword',
  api_ca_file             => '/etc/ssl/certs',
  api_ca_path             => '/etc/pki/certs',
  validate_tls            => false,
  location                => '/backups',
}
```

#### Delete a snapshot repository

```puppet
opensearch::snapshot_repository { 'backups':
  ensure   => 'absent',
  location => '/backup'
}
```

### Connection Validator

This module offers a way to make sure an instance has been started and is up and running before
doing a next action. This is done via the use of the `os_instance_conn_validator` resource.
```puppet
os_instance_conn_validator { 'myinstance' :
  server => 'es.example.com',
  port   => '9200',
}
```

A common use would be for example :

```puppet
class { 'kibana4' :
  require => Os_Instance_Conn_Validator['myinstance'],
}
```

### Package installation

There are two different ways of installing Opensearch:

#### Repository


##### Choosing an Opensearch major version

This module uses the `elastic/elastic_stack` module to manage package repositories. Because there is a separate repository for each major version of the Elastic stack, selecting which version to configure is necessary to change the default repository value, like this:


```puppet
class { 'opensearch::repo':
  version => 2,
}

class { 'opensearch':
  version => '2.4.1',
}
```

##### Manual repository management

You may want to manage repositories manually. You can disable automatic repository management like this:

```puppet
class { 'opensearch':
  manage_repo => false,
}
```

#### Remote package source

When a repository is not available or preferred you can install the packages from a remote source:

##### http/https/ftp

```puppet
class { 'opensearch':
  package_url => 'https://example.org/opensearch-2.4.1.deb',
  proxy_url   => 'http://proxy.example.com:8080/',
}
```

Setting `proxy_url` to a location will enable download using the provided proxy
server.
This parameter is also used by `opensearch::plugin`.
Setting the port in the `proxy_url` is mandatory.
`proxy_url` defaults to `undef` (proxy disabled).

##### puppet://
```puppet
class { 'opensearch':
  package_url => 'puppet:///path/to/opensearch-2.4.1.deb'
}
```

##### Local file

```puppet
class { 'opensearch':
  package_url => 'file:/path/to/opensearch-2.4.1.deb'
}
```

### JVM Configuration

When configuring opensearch's memory usage, you can modify it by setting `jvm_options`:

```puppet
class { 'opensearch':
  jvm_options => [
    '-Xms4g',
    '-Xmx4g'
  ]
}
```

### Service management

Currently only the basic SysV-style [init](https://en.wikipedia.org/wiki/Init) and [Systemd](http://en.wikipedia.org/wiki/Systemd) service providers are supported, but other systems could be implemented as necessary (pull requests welcome).

#### Defaults File

The *defaults* file (`/etc/default/opensearch` or `/etc/sysconfig/opensearch`) for the Opensearch service can be populated as necessary.
This can either be a static file resource or a simple key value-style  [hash](http://docs.puppetlabs.com/puppet/latest/reference/lang_datatypes.html#hashes) object, the latter being particularly well-suited to pulling out of a data source such as Hiera.

##### File source

```puppet
class { 'opensearch':
  init_defaults_file => 'puppet:///path/to/defaults'
}
```

## Advanced features

### Security

File-based users, roles, and certificates can be managed by this module.

**Note**: If you are planning to use these features, it is *highly recommended* you read the following documentation to understand the caveats and extent of the resources available to you.

#### Roles

Roles in the file realm can be managed using the `opensearch::role` type.
For example, to create a role called `myrole`, you could use the following resource:

```puppet
opensearch::role { 'myrole':
  privileges => {
    'cluster' => [ 'monitor' ],
    'indices' => [{
      'names'      => [ '*' ],
      'privileges' => [ 'read' ],
    }]
  }
}
```

This role would grant users access to cluster monitoring and read access to all indices.
See the [Security](https://opensearch.org/docs/latest/security-plugin/configuration/configuration/) documentation for your version to determine what `privileges` to use and how to format them (the Puppet hash representation will simply be translated into yaml.)

**Note**: The Puppet provider for `opensearch_user` has fine-grained control over the `roles.yml` file and thus will leave the default roles in-place.
If you would like to explicitly purge the default roles (leaving only roles managed by puppet), you can do so by including the following in your manifest:

```puppet
resources { 'opensearch_role':
  purge => true,
}
```

##### Mappings

Associating mappings with a role for file-based management is done by passing an array of strings to the `mappings` parameter of the `opensearch::role` type.
For example, to define a role with mappings:

```puppet
opensearch::role { 'logstash':
  mappings   => [
    'cn=group,ou=devteam',
  ],
  privileges => {
    'cluster' => 'manage_index_templates',
    'indices' => [{
      'names'      => ['logstash-*'],
      'privileges' => [
        'write',
        'delete',
        'create_index',
      ],
    }],
  },
}
```

If you'd like to keep the mappings file purged of entries not under Puppet's control, you should use the following `resources` declaration because mappings are a separate low-level type:

```puppet
resources { 'opensearch_role_mapping':
  purge => true,
}
```

#### Users

Users can be managed using the `opensearch::user` type.
For example, to create a user `mysuser` with membership in `myrole`:

```puppet
opensearch::user { 'myuser':
  password => 'mypassword',
  roles    => ['myrole'],
}
```

The `password` parameter will also accept password hashes generated from the `esusers`/`users` utility and ensure the password is kept in-sync with the Shield `users` file for all Opensearch instances.

```puppet
opensearch::user { 'myuser':
  password => '$2a$10$IZMnq6DF4DtQ9c4sVovgDubCbdeH62XncmcyD1sZ4WClzFuAdqspy',
  roles    => ['myrole'],
}
```

**Note**: When using the `osusers`/`users` provider (the default for plaintext passwords), Puppet has no way to determine whether the given password is in-sync with the password hashed by Opensearch.
In order to work around this, the `opensearch::user` resource has been designed to accept refresh events in order to update password values.
This is not ideal, but allows you to instruct the resource to change the password when needed.
For example, to update the aforementioned user's password, you could include the following your manifest:

```puppet
notify { 'update password': } ~>
opensearch::user { 'myuser':
  password => 'mynewpassword',
  roles    => ['myrole'],
}
```

#### Certificates

SSL/TLS can be enabled by providing the appropriate class params with paths to the certificate and private key files, and a password for the keystore.

```puppet
class { 'opensearch' :
  ssl                  => true,
  ca_certificate       => '/path/to/ca.pem',
  certificate          => '/path/to/cert.pem',
  private_key          => '/path/to/key.pem',
  keystore_password    => 'keystorepassword',
}
```

**Note**: Setting up a proper CA and certificate infrastructure is outside the scope of this documentation, see the aforementioned security guide for more information regarding the generation of these certificate files.

The module will set up a keystore file for the node to use and set the relevant options in `opensearch.yml` to enable TLS/SSL using the certificates and key provided.

#### System Keys

System keys can be passed to the module, where they will be placed into individual instance configuration directories.
This can be set at the `opensearch` class and inherited across all instances:

```puppet
class { 'opensearch':
  system_key => 'puppet:///path/to/key',
}
```

### Data directories

There are several different ways of setting data directories for Opensearch.
In every case the required configuration options are placed in the `opensearch.yml` file.

#### Default

By default we use:

    /var/lib/opensearch

Which mirrors the upstream defaults.

#### Single global data directory

It is possible to override the default data directory by specifying the `datadir` param:

```puppet
class { 'opensearch':
  datadir => '/var/lib/opensearch-data'
}
```

#### Multiple Global data directories

It's also possible to specify multiple data directories using the `datadir` param:

```puppet
class { 'opensearch':
  datadir => [ '/var/lib/os-data1', '/var/lib/os-data2']
}
```

See [the Opensearch documentation](https://opensearch.org/docs/latest/opensearch/cluster/) for additional information regarding this configuration.

### Opensearch configuration

The `config` option can be used to provide additional configuration options to Opensearch.

#### Configuration writeup

The `config` hash can be written in 2 different ways:

##### Full hash writeup

Instead of writing the full hash representation:

```puppet
class { 'opensearch':
  config                 => {
   'cluster'             => {
     'name'              => 'ClusterName',
     'routing'           => {
        'allocation'     => {
          'awareness'    => {
            'attributes' => 'rack'
          }
        }
      }
    }
  }
}
```

##### Short hash writeup

```puppet
class { 'opensearch':
  config => {
    'cluster' => {
      'name' => 'ClusterName',
      'routing.allocation.awareness.attributes' => 'rack'
    }
  }
}
```

##### Purging Secrets

By default, if a secret setting exists on-disk that is not present in the `secrets` hash, this module will leave it intact.
If you prefer to keep only secrets in the keystore that are specified in the `secrets` hash, use the `purge_secrets` boolean parameter either on the `opensearch` class to set it globally or per-instance.

##### Notifying Services

Any changes to keystore secrets will notify running opensearch services by respecting the `restart_on_change` and `restart_config_change` parameters.

## Development

Please see the [CONTRIBUTING.md](https://github.com/voxpupuli/puppet-elasticsearch/blob/master/.github/CONTRIBUTING.md) file for instructions regarding development environments and testing.

## Support

The Puppet Opensearch module is community supported and not officially supported by Opensearch Support.
