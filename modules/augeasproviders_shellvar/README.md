[![Puppet Forge Version](http://img.shields.io/puppetforge/v/herculesteam/augeasproviders_shellvar.svg)](https://forge.puppetlabs.com/herculesteam/augeasproviders_shellvar)
[![Puppet Forge Downloads](http://img.shields.io/puppetforge/dt/herculesteam/augeasproviders_shellvar.svg)](https://forge.puppetlabs.com/herculesteam/augeasproviders_shellvar)
[![Puppet Forge Endorsement](https://img.shields.io/puppetforge/e/herculesteam/augeasproviders_shellvar.svg)](https://forge.puppetlabs.com/herculesteam/augeasproviders_shellvar)
[![Build Status](https://img.shields.io/travis/hercules-team/augeasproviders_shellvar/master.svg)](https://travis-ci.org/hercules-team/augeasproviders_shellvar)
[![Coverage Status](https://img.shields.io/coveralls/hercules-team/augeasproviders_shellvar.svg)](https://coveralls.io/r/hercules-team/augeasproviders_shellvar)


# shellvar: type/provider for shell files for Puppet

This module provides a new type/provider for Puppet to read and modify shell
config files using the Augeas configuration library.

The advantage of using Augeas over the default Puppet `parsedfile`
implementations is that Augeas will go to great lengths to preserve file
formatting and comments, while also failing safely when needed.

This provider will hide *all* of the Augeas commands etc., you don't need to
know anything about Augeas to make use of it.

## Requirements

Ensure both Augeas and ruby-augeas 0.3.0+ bindings are installed and working as
normal.

See [Puppet/Augeas pre-requisites](http://docs.puppetlabs.com/guides/augeas.html#pre-requisites).

## Installing

The module can be installed easily ([documentation](http://docs.puppetlabs.com/puppet/latest/reference/modules_installing.html)):

    puppet module install herculesteam/augeasproviders_shellvar


## Documentation and examples

Type documentation can be generated with `puppet doc -r type` or viewed on the
[Puppet Forge page](http://forge.puppetlabs.com/herculesteam/augeasproviders_shellvar).

### manage simple entry

    shellvar { "HOSTNAME":
      ensure => present,
      target => "/etc/sysconfig/network",
      value  => "host.example.com",
    }

    shellvar { "disable rsyncd":
      ensure   => present,
      target   => "/etc/default/rsync",
      variable => "RSYNC_ENABLE",
      value    => "false",
    }

    shellvar { "ntpd options":
      ensure   => present,
      target   => "/etc/sysconfig/ntpd",
      variable => "OPTIONS",
      value    => "-g -x -c /etc/myntp.conf",
    }

### manage entry with comment

    shellvar { "HOSTNAME":
      ensure  => present,
      target  => "/etc/sysconfig/network",
      comment => "My server's hostname",
      value   => "host.example.com",
    }

### export values

    shellvar { "HOSTNAME":
      ensure  => exported,
      target  => "/etc/sysconfig/network",
      value   => "host.example.com",
    }

### unset values

    shellvar { "HOSTNAME":
      ensure  => unset,
      target  => "/etc/sysconfig/network",
    }

### force quoting style

Values needing quotes will automatically get them, but they can also be
explicitly enabled.  Unfortunately the provider doesn't help with quoting the
values themselves.

    shellvar { "RSYNC_IONICE":
      ensure   => present,
      target   => "/etc/default/rsync",
      value    => "-c3",
      quoted   => "single",
    }

### delete entry

    shellvar { "RSYNC_IONICE":
      ensure => absent,
      target => "/etc/default/rsync",
    }

### remove comment from entry

    shellvar { "HOSTNAME":
      ensure  => present,
      target  => "/etc/sysconfig/network",
      comment => "",
    }

### replace commented value with entry

    shellvar { "HOSTNAME":
      ensure    => present,
      target    => "/etc/sysconfig/network",
      value     => "host.example.com",
      uncomment => true,
    }

### uncomment a value

    shellvar { "HOSTNAME":
      ensure    => present,
      target    => "/etc/sysconfig/network",
      uncomment => true,
    }

### array values

You can pass array values to the type.

There are two ways of rendering array values, and the behavior is set using
the `array_type` parameter. `array_type` takes three possible values:

* `auto` (default): detects the type of the existing variable, defaults to `string`;
* `string`: renders the array as a string, with a space as element separator;
* `array`: renders the array as a shell array.

For example:

    shellvar { "PORTS":
      ensure     => present,
      target     => "/etc/default/puppetmaster",
      value      => ["18140", "18141", "18142"],
      array_type => "auto",
    }

will create `PORTS="18140 18141 18142"` by default, and will change `PORTS=(123)` to `PORTS=("18140" "18141" "18142")`.

    shellvar { "PORTS":
      ensure     => present,
      target     => "/etc/default/puppetmaster",
      value      => ["18140", "18141", "18142"],
      array_type => "string",
    }

will create `PORTS="18140 18141 18142"` by default, and will change `PORTS=(123)` to `PORTS="18140 18141 18142"`.

    shellvar { "PORTS":
      ensure     => present,
      target     => "/etc/default/puppetmaster",
      value      => ["18140", "18141", "18142"],
      array_type => "array",
    }

will create `PORTS=("18140" "18141" "18142")` by default, and will change `PORTS=123` to `PORTS=(18140 18141 18142)`.

Quoting is honored for arrays:

* When using the string behavior, quoting is global to the string;
* When using the array behavior, each value in the array is quoted as requested.

### appending to arrays

    shellvar { "GRUB_CMDLINE_LINUX":
      ensure       => present,
      target       => "/etc/default/grub",
      value        => "cgroup_enable=memory",
      array_append => true,
    }

will change `GRUB_CMDLINE_LINUX="quiet splash"` to `GRUB_CMDLINE_LINUX="quiet splash cgroup_enable=memory"`.

    shellvar { "GRUB_CMDLINE_LINUX":
      ensure       => present,
      target       => "/etc/default/grub",
      value        => ["quiet", "cgroup_enable=memory"],
      array_append => true,
    }

will also change `GRUB_CMDLINE_LINUX="quiet splash"` to `GRUB_CMDLINE_LINUX="quiet splash cgroup_enable=memory"`.

### removing from arrays

    shellvar { "GRUB_CMDLINE_LINUX":
      ensure       => absent,
      target       => "/etc/default/grub",
      value        => "cgroup_enable=memory",
      array_append => true,
    }

will change `GRUB_CMDLINE_LINUX="quiet splash cgroup_enable=memory"` to `GRUB_CMDLINE_LINUX="quiet splash"`.

    shellvar { "GRUB_CMDLINE_LINUX":
      ensure       => absent,
      target       => "/etc/default/grub",
      value        => ["quiet", "cgroup_enable=memory"],
      array_append => true,
    }

will also change `GRUB_CMDLINE_LINUX="splash cgroup_enable=memory"` to `GRUB_CMDLINE_LINUX="splash"`.

## Issues

Please file any issues or suggestions [on GitHub](https://github.com/hercules-team/augeasproviders_shellvar/issues).
