# ==  Class puppetdb:
#
# Sets up the puppetdb clojure app.
# This assumes you're using
#
class puppetdb(
    $db_rw_host = hiera('puppetdb::db_rw_host', 'localhost'),
    $db_ro_host = hiera('puppetdb::db_ro_host', undef),
    $db_user = hiera('puppetdb::db_user', 'puppetdb'),
    $db_password = hiera('puppetdb::db_password', 'test'),
    $perform_gc = hiera('puppetdb::perform_gc', false),
    $heap_size = hiera('puppetdb::heap_size', '4G'),
    $bind_ip = hiera('puppetdb::bind_ip', '0.0.0.0'),
    $command_processing_threads = hiera('puppetdb::command_processing_threads', 16),
    $db_ssl = hiera('puppetdb::db_ssl', false),
) {

    package { 'java7-runtime-headless':
	    ensure => present,
	}

    ## PuppetDB installation

    ## Update puppetdb when wmf do.
    exec { "install_puppetdb":
        command => '/usr/bin/curl -o /opt/puppetdb_2.3.8-1~wmf1_all.deb https://apt.wikimedia.org/wikimedia/pool/main/p/puppetdb/puppetdb_2.3.8-1~wmf1_all.deb',
        unless  => '/bin/ls /opt/puppetdb_2.3.8-1~wmf1_all.deb',
    }

    exec { "puppetdb-terminus":
        command => '/usr/bin/curl -o /opt/puppetdb-terminus_2.3.8-1~wmf1_all.deb https://apt.wikimedia.org/wikimedia/pool/main/p/puppetdb/puppetdb-terminus_2.3.8-1~wmf1_all.deb',
        unless  => '/bin/ls /opt/puppetdb-terminus_2.3.8-1~wmf1_all.deb',
    }

    package { "puppetdb":
        provider => dpkg,
        ensure   => present,
        source   => '/opt/puppetdb_2.3.8-1~wmf1_all.deb',
        require  => Package['java7-runtime-headless'],
    }

    package { "puppetdb-terminus":
        provider => dpkg,
        ensure   => present,
        source   => '/opt/puppetdb-terminus_2.3.8-1~wmf1_all.deb',
    }

    ## Configuration

    file { '/etc/puppetdb/conf.d':
        ensure  => directory,
        owner   => 'puppetdb',
        group   => 'puppetdb',
        mode    => '0750',
        recurse => true,
        require => Package['puppetdb'],
    }

    # Ensure the default debian config file is not there

    file { '/etc/puppetdb/conf.d/config.ini':
        ensure => absent,
    }

    if $db_ssl {
      $ssl = '?ssl=true'
    } else {
      $ssl = ''
    }

    $default_db_settings = {
        'classname'   => 'org.postgresql.Driver',
        'subprotocol' => 'postgresql',
        'username'    => 'puppetdb',
        'password'    => $db_password,
        'subname'     => "//${db_rw_host}:5432/puppetdb${ssl}",
    }

    if $perform_gc {
        $db_settings = merge(
            $default_db_settings,
            { 'report-ttl' => '1d', 'gc-interval' => '20' }
        )
    } else {
        $db_settings = $default_db_settings
    }

    puppetdb::config { 'database':
        settings => $db_settings,
    }

    #read db settings
    if $db_ro_host {
        $read_db_settings = merge(
            $default_db_settings,
            {'subname' => "//${db_ro_host}:5432/puppetdb${ssl}"}
        )
        puppetdb::config { 'read-database':
            settings => $read_db_settings,
        }
    }

    puppetdb::config { 'global':
        settings => {
            'vardir'         => '/var/lib/puppetdb',
            'logging-config' => '/etc/puppetdb/logback.xml',
        },
    }

    puppetdb::config { 'repl':
        settings => {'enabled' => false},
    }

    $jetty_settings = {
        'port'        => 8080,
        'ssl-port'    => 8081,
        'ssl-key'     => '/etc/puppetdb/ssl/private.pem',
        'ssl-cert'    => '/etc/puppetdb/ssl/public.pem',
        'ssl-ca-cert' => '/etc/puppetdb/ssl/ca.pem',
    }

    if $bind_ip {
        $actual_jetty_settings = merge($jetty_settings, {'ssl-host' => $bind_ip})
    } else {
        $actual_jetty_settings = $jetty_settings
    }

    puppetdb::config { 'jetty':
        settings => $actual_jetty_settings,
    }

    package { 'policykit-1':
        ensure => present,
    }

    file { '/lib/systemd/system/puppetdb.service':
        ensure  => present,
        content => template('puppetdb/puppetdb.systemd.erb'),
        require => Package['policykit-1'],
    }

    service { 'puppetdb':
        ensure  => running,
        require => File['/lib/systemd/system/puppetdb.service'],
    }

    puppetdb::config { 'command-processing':
        settings => {
            'threads' => $command_processing_threads,
        },
    }

}
