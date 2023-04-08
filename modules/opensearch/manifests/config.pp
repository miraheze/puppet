# This class exists to coordinate all configuration related actions,
# functionality and logical units in a central place.
#
# It is not intended to be used directly by external resources like node
# definitions or other modules.
#
# @example importing this class into other classes to use its functionality:
#   class { 'opensearch::config': }
#
# @author Richard Pijnenburg <richard.pijnenburg@elasticsearch.com>
# @author Tyler Langlois <tyler.langlois@elastic.co>
# @author Gavin Williams <gavin.williams@elastic.co>
#
class opensearch::config {
  #### Configuration

  Exec {
    path => ['/bin', '/usr/bin', '/usr/local/bin'],
    cwd  => '/',
  }

  $init_defaults = {
    'MAX_OPEN_FILES' => '65535',
  }.merge($opensearch::init_defaults)

  if ($opensearch::ensure == 'present') {
    file {
      $opensearch::homedir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user;
      $opensearch::configdir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user,
        mode   => '2750';
      $opensearch::datadir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user,
        mode   => '2750';
      $opensearch::logdir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user,
        mode   => '2750';
      $opensearch::real_plugindir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user,
        mode   => 'o+Xr';
      "${opensearch::homedir}/lib":
        ensure  => 'directory',
        group   => '0',
        owner   => 'root',
        mode    => '0755',
        recurse => true;
    }

    # Defaults file, either from file source or from hash to augeas commands
    if ($opensearch::init_defaults_file != undef) {
      file { "${opensearch::defaults_location}/opensearch":
        ensure => $opensearch::ensure,
        source => $opensearch::init_defaults_file,
        owner  => 'root',
        group  => $opensearch::opensearch_group,
        mode   => '0660',
        before => Service[$opensearch::service_name],
        notify => $opensearch::_notify_service,
      }
    } else {
      augeas { "${opensearch::defaults_location}/opensearch":
        incl    => "${opensearch::defaults_location}/opensearch",
        lens    => 'Shellvars.lns',
        changes => template("${module_name}/etc/sysconfig/defaults.erb"),
        before  => Service[$opensearch::service_name],
        notify  => $opensearch::_notify_service,
      }
    }

    # Generate config file
    $_config = deep_implode($opensearch::config)

    # Generate SSL config
    if $opensearch::ssl {
      if ($opensearch::keystore_password == undef) {
        fail('keystore_password required')
      }

      if ($opensearch::keystore_path == undef) {
        $_keystore_path = "${opensearch::configdir}/opensearch.ks"
      } else {
        $_keystore_path = $opensearch::keystore_path
      }

      $_tls_config = {
        'plugins.security.ssl.http.enabled'                => true,
        'plugins.security.ssl.http.keystore_filepath'      => $_keystore_path,
        'plugins.security.ssl.http.keystore_password'      => $opensearch::keystore_password,
        'plugins.security.ssl.transport.enabled'           => true,
        'plugins.security.ssl.transport.keystore_filepath' => $_keystore_path,
        'plugins.security.ssl.transport.keystore_password' => $opensearch::keystore_password,
      }

      # Trust CA Certificate
      java_ks { 'opensearch_ca':
        ensure       => 'latest',
        certificate  => $opensearch::ca_certificate,
        target       => $_keystore_path,
        password     => $opensearch::keystore_password,
        trustcacerts => true,
      }

      # Load node certificate and private key
      java_ks { 'opensearch_node':
        ensure      => 'latest',
        certificate => $opensearch::certificate,
        private_key => $opensearch::private_key,
        target      => $_keystore_path,
        password    => $opensearch::keystore_password,
      }
    } else {
      $_tls_config = {}
    }

    # Generate Opensearch config
    $data = merge(
      $opensearch::config,
      { 'path.data' => $opensearch::datadir },
      { 'path.logs' => $opensearch::logdir },
      $_tls_config
    )

    file { "${opensearch::configdir}/opensearch.yml":
      ensure  => 'file',
      content => template("${module_name}/etc/opensearch/opensearch.yml.erb"),
      notify  => $opensearch::_notify_service,
      require => Class['opensearch::package'],
      owner   => $opensearch::opensearch_user,
      group   => $opensearch::opensearch_group,
      mode    => '0440',
    }

    # Add any additional JVM options
    $_epp_hash = {
      sorted_jvm_options => sort(unique($opensearch::jvm_options)),
    }
    file { "${opensearch::configdir}/jvm.options.d/jvm.options":
      ensure  => 'file',
      content => epp("${module_name}/etc/opensearch/jvm.options.d/jvm.options.epp", $_epp_hash),
      owner   => $opensearch::opensearch_user,
      group   => $opensearch::opensearch_group,
      mode    => '0640',
      notify  => $opensearch::_notify_service,
    }

    if $opensearch::system_key != undef {
      file { "${opensearch::configdir}/system_key":
        ensure => 'file',
        source => $opensearch::system_key,
        mode   => '0400',
      }
    }

    # Add secrets to keystore
    if $opensearch::secrets != undef {
      opensearch_keystore { 'opensearch_secrets':
        configdir => $opensearch::configdir,
        purge     => $opensearch::purge_secrets,
        settings  => $opensearch::secrets,
        notify    => $opensearch::_notify_service,
      }
    }
  } elsif ( $opensearch::ensure == 'absent' ) {
    file { $opensearch::real_plugindir:
      ensure => 'absent',
      force  => true,
      backup => false,
    }

    file { "${opensearch::defaults_location}/opensearch":
      ensure    => 'absent',
      subscribe => Service[$opensearch::service_name],
    }
  }
}
