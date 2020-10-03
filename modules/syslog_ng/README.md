# syslog_ng

[![Build Status](https://travis-ci.org/ccin2p3/puppet-syslog_ng.png?branch=master)](https://travis-ci.org/ccin2p3/puppet-syslog_ng)

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
    * [Configuration syntax](#statement_syntax)
3. [Setup - The basics of getting started with syslog_ng](#setup)
    * [Puppet Forge](#puppet-forge)
    * [Installing from source](#installing-from-source)
    * [What syslog_ng affects](#what-syslog_ng-affects)
    * [Getting started with syslog_ng](#beginning-with-syslog_ng)
4. [Usage - Configuration options and additional functionality](#usage)
    * [Facts](#facts)
    * [Classes and defined types](#classes-and-defined-types)
5. [Implementation details](#implementation-details)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
    * [Preparation to run the tests](#preparations-to-run-the-tests)
    * [Running the tests](#running-the-tests)
    * [The workflow](#the-workflow)
    * [Other information](#other-information)
    * [Changelog](#changelog)

## Overview
This module lets you generate syslog-ng configuration using puppet. It supports
all kinds of statements, such as sources, destinations, templates, and so on. After
defining them, you can combine them into a log path. This module also takes care of
installing syslog-ng, or reloading it after a configuration file change.

You can check the supported platforms in the [Limitations](#limitations) section.

## Module Description
This module integrates well with syslog-ng. It supports its configuration model
 so you can create new sources and destinations as Puppet resources. Under the
 hood they are just defined resource types.

The supported statements:
 * `options`
 * `template`
 * `rewrite`
 * `parser`
 * `filter` (partial support)
 * `source`
 * `destination`
 * `log`
 * +1: `config`, which lets you insert existing configuration snippets.

Each type is under the `syslog_ng::` namespace, so you can use them like this:
```
syslog_ng::source { 's_gsoc':
    params => {
        'type' => 'tcp',
        'options' => [
            {'ip' => "'127.0.0.1'"},
            {'port' => 1999}
        }]
    }
}
```
There is a shorter form:
<a name="shorter_form"></a>
```
syslog_ng::source { 's_gsoc':
    params => {
        'tcp' => [
            {'ip' => "'127.0.0.1'"},
            {'port' => 1999}
        }]
    }
}
```

### <a name="statement_syntax"></a> Configuration syntax
Every statement has the same layout. They can accept a `params` parameter, which
can be a hash or an array of hashes. Each hash should have a `type` and `options`
key or you can use a [shorter form](#shorter_form).

The value of the `type` represents the type of the statement, in case of a
source this can be `file`, `tcp` and so on.

The value of the `options` is an array of strings and hashes. You have to pay attention to
quotation when using strings. If you want the inner quotation to be a single quote (
in the `syslog-ng.conf`), then the outer one must be a double, like
 `"'this string'"`, which will be transformed into `'this string'`.

Similarly, you can write `'"this string"''` to get `"this string"` in the
configuration.

By using this convention, the module will generate correct configuration files.
If the `option` array is empty, you can use an empty string `''` instead.

As I mentioned, there are strings and hashes in an option. Hashes
must contain only one key. This key will identify the name of the parameter and its
value must be an array of strings. If that would contain only one item, the value can
be simply just a string.

You can find a lot of examples under the `tests` and `spec` directories. The
`default_config.pp` under  the `tests` directory contains the default configuration
 from the `syslog-ng` source, translated into Puppet types.
## Setup

### Puppet Forge
This module is published on [Puppet Forge](https://forge.puppetlabs.com/ccin2p3/syslog_ng).
It used to be under the [ihrwein](https://forge.puppetlabs.com/ihrwein/syslog_ng) namespace, but the original author kindly accepted to hand it over.

### Installing from source
You can install it following these steps:

 0. Make sure you have the required dependencies
 * ruby
 * bundler
 1. Clone the source code into a directory:
 ```
 $ git clone https://github.com/ccin2p3/puppet-syslog_ng.git
 ```
 2. Make sure you are on master branch:
 ```
 $ git checkout master
 ```
 3. Get dependencies
 ```
 $ bundle install
 ```
 4. Build a package:
 ```
 $ bundle exec puppet module build
 ```
This will create a `tar.gz` file under the `pkg` directory. Now you should be able
to install the module:
 ```
 $ bundle exec puppet module install pkg/ccin2p3-syslog_ng-VERSION.tar.gz
 ```

### What syslog_ng affects
* It setup a repository with recent syslog-ng releases (only on RedHat and
  Debian based operating systems and if `$syslog_ng::manage_repo` is set to
  `true`)
* It installs the `syslog-ng` or `syslog-ng-core` package
  * that creates the necessary directories on your system, including `/etc/syslog-ng`.
  * If another `syslog` daemon is installed, it will be removed by your package manager.
* purges the content of `/etc/syslog-ng/syslog-ng.conf`

### Getting started with syslog_ng
If you are not familiar with `syslog-ng`, I suggest you to take a look at the
[Syslog-ng Admin Guide](http://www.balabit.com/sites/default/files/documents/syslog-ng-ose-3.5-guides/en/syslog-ng-ose-v3.5-guide-admin/html-single/index.html)  which contains all the necessary information to use this
software.

You can also get help on the [syslog-ng mailing list](syslog-ng@lists.balabit.hu).

## Usage
Just use the [classes and defined types](#Classes-and-defined-types) as you would
 use them, without Puppet.

Before the generated configuration would be applied, it is written to a temporary
 file. Next, the module checks the configuration syntax of this file, and if it is OK,
 it overwrites the real configuration file. So you do not have to worry about
 configuration errors.

### Facts

The fact `syslog_ng_version` contains the installed version string *e.g.* `3.7.1`

### Classes and defined types

#### Class: `syslog_ng`
The main class of this module. By including it you get an installed `syslog-ng`
with default configuration on your system.

**Parameters within `syslog_ng`:**

##### `config_file`
Configures the path of the configuration file. Defaults to `/etc/syslog-ng/syslog-ng.conf` on
all operation systems.
##### `manage_repo`
Controls if the module is managing the unofficial repositories of syslog-ng packages.  Use `true` if you want to use the latest version of syslog-ng from the [unofficial Debian repository](https://www.syslog-ng.com/community/b/blog/posts/installing-the-latest-syslog-ng-on-ubuntu-and-other-deb-distributions) or [unofficial RedHat repository](https://www.syslog-ng.com/community/b/blog/posts/installing-latest-syslog-ng-on-rhel-and-other-rpm-distributions).  Defaults to `false`.
##### `manage_package`
Controls if the module is managing the package resource or not. Use `false` if you are already handling this in your manifests. Defaults to `true`
##### `manage_init_defaults`
Controls if the module is managing the init script's config file (See `init_config_file` and `init_config_hash`). Defaults to `true`
##### `modules`
Configures additional syslog-ng modules. If `manage_package` is set to `true` this will also install the corresponding packages, *e.g.* `syslog-ng-riemann` on RedHat if
`modules = ['riemann']`.
##### `sbin_path`
Configures the path, where `syslog-ng` and `syslog-ng-ctl` binaries can be found.
Defaults to `/usr/sbin`.
##### `user`
Configures `syslog-ng` to run as `user`.
##### `group`
Configures `syslog-ng` to run as `group`.
##### `syntax_check_before_reloads`
The module always checks the syntax of the generated configuration. If it is not OK,
 the main configuration (usually `/etc/syslog-ng/syslog-ng.conf`) will not be
 overwritten, but you can disable this behavior by setting this parameter to false.
##### `init_config_file`
Path to the init script configuration file, defaults to `/etc/sysconfig/syslog-ng` on RedHat systems, and `/etc/default/syslog-ng` on Debian family.
##### `init_config_hash`
Hash of init configuration options to put into `init_config_file`. This has OS specific defaults which will be merged to user specified value.

#### Defined type: `syslog_ng::config`
Some elements of the syslog-ng DSL are not supported by this module (mostly
  the boolean operators in filters) so you may want to keep some configuration
  snippets in their original form. This type lets you write texts into the configuration
  without any parsing or processing.

Every configuration file begins with a `@version: <version>` line. You can use
 this type to write this line into the configuration, make comments or use
 existing snippets.

```puppet
syslog_ng::config {'version':
    content => '@version: 3.6',
    order => '02'
}
```
**Parameters within `syslog_ng::config`:**
##### `content`
Configures the text which must be written into the configuration file. A
 newline character is automatically appended to its end.

##### `order`
Sets the order of this snippet in the configuration file. See
[Implementation](#implementation). If you want to write the version line, the
`order => '02'` is suggested, because the auto generated header has order '01'.


#### Defined type: `syslog_ng::destination`
Creates a destination in your configuration.
```puppet
syslog_ng::destination { 'd_udp':
    params => {
        'type' => 'udp',
        'options' => [
            "'127.0.0.1'",
            {'port' => '1999'},
            {'localport' => '999'}
        ]
    }
}
```
**Parameters within `syslog_ng::destination`:**
##### `params`
An array of hashes or a single hash. It uses the syntax described
[here](#statement_syntax).

#### Defined type: `syslog_ng::filter`
Creates a filter in your configuration. It **does not support binary operators**,
 such as `and` or `or`. Please, use a `syslog_ng::config` if you need this
 functionality.

```puppet
syslog_ng::filter {'f_tag_filter':
    params => {
        'type' => 'tags',
        'options' => [
            '".classifier.system"'
        ]
    }
}
```
**Parameters within `syslog_ng::filter`:**
##### `params`
An array of hashes or a single hash. It uses the syntax described
[here](#statement_syntax).

#### Defined type: `syslog_ng::log`
Creates log paths in your configuration. It can create `channels`, `junctions`
 and reference already defined `sources`, `destinations`, etc.  The syntax is a
 little bit different then the one previously described under statements.

Here is a simple rule: if you want to reference an already defined type (e.g. `s_gsoc2014`) use a hash with one key-value pair. The key must be the type of the statement (e.g. `source`) and the value must be its title.

If you do not specify a reference, use an array instead. Take a look at the example below:

```puppet
syslog_ng::log {'l2':
    params => [
        {'source' => 's_gsoc2014'},
        {'junction' => [
            {
            'channel' => [
                {'filter' => 'f_json'},
                {'parser' => 'p_json'}
            ]},
            {
            'channel' => [
                {'filter' => 'f_not_json'},
                {'flags' => 'final'}
            ]}
        ]
        },
        {'destination' => 'd_gsoc'}
    ]
}
```
**Parameters within `syslog_ng::log`:**
##### `params`
The syntax is a bit different, but you can find examples under the `tests` directory.


#### Defined type: `syslog_ng::options`
Creates a global options statement. Currently it is not a class, so you should
 not declare it multiple times! It is not defined as a class, so you can declare it as other similar types.

```puppet
syslog_ng::options { "global_options":
    options => {
        'bad_hostname' => "'no'",
        'time_reopen'  => 10
    }
}
```
**Parameters within `syslog_ng::options`:**
##### `options`
A hash containing string keys and string values. In the generated configuration
the keys will appear in alphabetical order.


#### Class: `syslog_ng::params`
Contains some basic constants which are used during the configuration generation.
 It is the base class of `syslog_ng`. You should not use this class directly, it
 is part of the inner implementation.

####Defined type: `syslog_ng::parser`
Creates a parser statement in your configuration.

```puppet
syslog_ng::parser {'p_hostname_segmentation':
    params => {
        'type' => 'csv-parser',
        'options' => [
            {'columns' => [
                '"HOSTNAME.NAME"',
                '"HOSTNAME.ID"'
            ]},
            {'delimiters' => '"-"'},
            {'flags' => 'escape-none'},
            {'template' => '"${HOST}"'}
        ]
    }
}
```
**Parameters within `syslog_ng::parser`:**
##### `params`
An array of hashes or a single hash. It uses the syntax which is described
[here](#statement_syntax).


#### Class: `syslog_ng::reload`
Contains a logic, which is able to reload `syslog-ng`. You should not use this
class directly, it is part of the inner implementation.


#### Defined type: `syslog_ng::rewrite`
Creates one or more rewrite rules in your configuration.

```puppet
syslog_ng::rewrite{'r_rewrite_subst':
    params => {
        'type' => 'subst',
        'options' => [
            '"IP"',
            '"IP-Address"',
            {'value' => '"MESSAGE"'},
            {'flags' => 'global'}
        ]
    }
}
```
**Parameters within `syslog_ng::rewrite`:**
##### `params`
An array of hashes or a single hash. It uses the syntax which is described
[here](#statement_syntax).


#### Defined type: `syslog_ng::source`
Creates a source in your configuration.

```puppet
syslog_ng::source { 's_gsoc':
    params => {
        'type' => 'tcp',
        'options' => [
          { 'ip' => "'127.0.0.1'" },
          { 'port' => 1999 }
        ]
    }
}

syslog_ng::source {'s_external':
    params => [
        { 'type' => 'udp',
          'options' => [
            {'ip' => ["'127.0.0.1'"]},
            {'port' => [514]}
            ]
        },
        { 'type' => 'tcp',
          'options' => [
            {'ip' => ["'127.0.0.1'"]},
            {'port' => [514]}
            ]
        },
        {
          'type' => 'syslog',
          'options' => [
            {'flags' => ['no-multi-line', 'no-parse']},
            {'ip' => ["'127.0.0.1'"]},
            {'keep-alive' => ['yes']},
            {'keep_hostname' => ['yes']},
            {'transport' => ['udp']}
            ]
        }
    ]
}
```
**Parameters within `syslog_ng::source`:**
##### `params`
An array of hashes or a single hash. It uses the syntax which is described
[here](#statement_syntax).


#### Defined type: `syslog_ng::template`
Creates one or more templates in your configuration.

```puppet
syslog_ng::template {'t_demo_filetemplate':
    params => [
        {
            'type' => 'template',
            'options' => [
                '"$ISODATE $HOST $MSG\n"'
            ]
        },
        {
            'type' => 'template_escape',
            'options' => [
                'no'
            ]
        }
    ]
}
```
**Parameters within `syslog_ng::template`:**
##### `params`
An array of hashes or a single hash. It uses the syntax which is described
[here](#statement_syntax).


## Implementation details

There is a `concat::fragment` resource in every class or defined type which represents a statement. Because statements need to be defined before they are referenced in the configuration, I use an automatic ordering system. Each type has its own order value, which determines its position in the configuration file. The smaller an order value is, the more likely it will be at the beginning of the file. The interval of these values starts with `0` and are `'strings'`. Here is a table, which contains the default order values:
<a name="order_table"></a>

| Name                   | Order |
|------------------------|-------|
| syslog_ng::config      | '5'     |
| syslog_ng::destination | '70'    |
| syslog_ng::filter      | '50'    |
| syslog_ng::log         | '80'    |
| syslog_ng::options     | '10'    |
| syslog_ng::parser      | '40'    |
| syslog_ng::rewrite     | '30'    |
| syslog_ng::source      | '60'    |
| syslog_ng::template    | '20'    |

The config generation is done by the `generate_statement()` function in most
 cases. It is just a wrapper around my `statement.rb` Ruby module, which does
 the hard work. The `require` part may seem quite ugly, but it works well.


## Limitations

The module works well with the following Puppet versions:
  * 2.7.9
  * 2.7.13
  * 2.7.17
  * 3.1.0
  * 3.2.3
  * 3.3.1
  * 3.3.2
  * 3.4.0
  * 3.4.3

Tested Ruby versions:
  * 1.8.7
  * 1.9.2

*NOTE*: The module was tested with Travis with these versions. It may work well
 on other Puppet or Ruby versions. If that's so, please hit me up.

The following platforms are currently tested (in Docker containers):

|              | 1.8.7 | 1.9.1 | 1.9.3 | 2.0.0 |
|--------------|-------|-------|-------|-------|
| CentOS 6     | x     |       |       |       |
| CentOS 7      |       |       |       | x     |
| Ubuntu 12.04 | x     |       |       |       |
| Ubuntu 14.04 |       |       | x     |       |

If you use it on an other platform, please let me know about it!

## Development

### Unit tests

```
bundle install
bundle exec rake spec
```

or alternatively

```
pdk test unit
```

### Smoke tests

There are some examples in the `tests` directory.
These can be tested using `puppet apply tests/<test>.pp`.

### Docker

You can run the tests locally on multiple platform at the same time. Check the subdirs undes `docker/` about the currently used platforms and Ruby versions.

### Preparations to run the tests
You can run the tests on your machine, if you have `Docker`, `fig` and `make` installed. You can find more information [here](https://docs.docker.com/installation/) how to install Docker.

For fig, you can install it with pip:
```
sudo pip install fig
```

You can install make on Debian like systems with the following command:
```
sudo apt-get install make
```

### Running the tests
You can use `make` to run the tests:
* `make [all]:` build and run all tests on all platforms
* `make build:` build the Docker images
* `make check:` run the tests on all platforms
* `make ps`: check the exit codes of the platform tests
* `make logs:` view the test logs
* `make clean`: remove all temporary files

### The workflow
First, run `make` in the cloned repo. That will build the Docker images
and start the tests. It will output a lot of information, but the last
lines are the most substantial. They looks similar to these:
```
successfully built 0ff4aa52ce3a
fig up -d
Recreating ihrweinsyslogng_ubuntu1404ruby193_1...
Recreating ihrweinsyslogng_ubuntu1204ruby187_1...
fig ps
               Name                    Command    State   Ports
---------------------------------------------------------------
ihrweinsyslogng_ubuntu1204ruby187_1   rake spec   Up
ihrweinsyslogng_ubuntu1404ruby193_1   rake spec   Up
```
Now, you can check the progress with `make ps`. If they are not
runnnig, you can see the exit codes. 0 mean OK. 


### Other information

I am open to any pull requests, either for bug fixes or feature
 developments. I cannot stress the significance of tests sufficiently, so please,
 write some spec tests and update the documentation as well according to your
 modification.

**Note for commiters:**

The `master` branch is a sacred place, do not commit to it directly, we should touch it only using pull requests.
###  Changelog
