# Class: zookeeper::config
#
# This module manages the configuration directories
#
# PRIVATE CLASS - do not use directly (use main `zookeeper` class).
class zookeeper::config inherits zookeeper {
  file { $zookeeper::cfg_dir:
    ensure  => directory,
    owner   => $zookeeper::user,
    group   => $zookeeper::group,
    recurse => true,
    mode    => '0644',
  }

  file { $zookeeper::log_dir:
    ensure  => directory,
    owner   => $zookeeper::user,
    group   => $zookeeper::group,
    recurse => false,
    mode    => '0644',
  }

  file { $zookeeper::datastore:
    ensure  => directory,
    owner   => $zookeeper::user,
    group   => $zookeeper::group,
    mode    => '0644',
    recurse => false, # intentionally, puppet run would take too long #41
  }

  if $zookeeper::datalogstore {
    file { $zookeeper::datalogstore:
      ensure  => directory,
      owner   => $zookeeper::user,
      group   => $zookeeper::group,
      mode    => '0644',
      recurse => false, # intentionally, puppet run would take too long #41
    }
  }

  if $zookeeper::service_provider != 'exhibitor' {
    file { "${zookeeper::cfg_dir}/zoo.cfg":
      owner   => $zookeeper::user,
      group   => $zookeeper::group,
      mode    => '0644',
      content => template("${module_name}/conf/zoo.cfg.erb"),
    }

    # we should notify Class['::zookeeper::service'] however it's not configured
    # at this point (first run), so we have to subscribe from service declaration
    file { "${zookeeper::cfg_dir}/myid":
      ensure  => file,
      content => template("${module_name}/conf/myid.erb"),
      owner   => $zookeeper::user,
      group   => $zookeeper::group,
      mode    => '0644',
      require => File[$zookeeper::cfg_dir],
    }

    file { "${zookeeper::datastore}/myid":
      ensure => 'link',
      target => "${zookeeper::cfg_dir}/myid",
    }
  }

  file { "${zookeeper::cfg_dir}/${zookeeper::environment_file}":
    owner   => $zookeeper::user,
    group   => $zookeeper::group,
    mode    => '0644',
    content => template("${module_name}/conf/environment.erb"),
  }

  file { "${zookeeper::cfg_dir}/log4j.properties":
    owner   => $zookeeper::user,
    group   => $zookeeper::group,
    mode    => '0644',
    content => template("${module_name}/conf/log4j.properties.erb"),
  }

  file { "${zookeeper::cfg_dir}/logback.xml":
    owner   => $zookeeper::user,
    group   => $zookeeper::group,
    mode    => '0644',
    content => template("${module_name}/conf/logback.xml.erb"),
  }

  # Initialize the datastore if required
  if $zookeeper::initialize_datastore {
    exec { 'initialize_datastore':
      command => "${zookeeper::initialize_datastore_bin} --myid=${zookeeper::id}",
      user    => $zookeeper::user,
      creates => "${zookeeper::datastore}/version-2",
      require => [File[$zookeeper::datastore], Class['zookeeper::install']],
    }
  }
}
