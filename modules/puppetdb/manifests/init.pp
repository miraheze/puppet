# ==  Class puppetdb:
#
# Sets up the puppetdb clojure app.
# This assumes you're using
#
class puppetdb(
    $db_rw_host = hiera('puppetdb::db_rw_host', 'localhost'),
    $db_ro_host = hiera('puppetdb::db_ro_host', undef),
    $db_user = hiera('puppetdb::db_user', 'puppetdb'),
    $db_password = hiera('puppetdb::db_password'),
    $perform_gc = hiera('puppetdb::perform_gc', true),
    $jvm_opts = hiera('puppetdb::jvm_opts', '-Xmx160m'),
    $bind_ip = hiera('puppetdb::bind_ip', '0.0.0.0'),
    $command_processing_threads = hiera('puppetdb::command_processing_threads', 4),
    $db_ssl = hiera('puppetdb::db_ssl', false),
) {

    package { 'default-jdk':
        ensure => present,
    }

    ## PuppetDB installation

    include ::apt

    if !defined(Apt::Source['puppetdb_apt']) {
        apt::source { 'puppetdb_apt':
            comment  => 'puppetdb',
            location => 'http://apt.wikimedia.org/wikimedia',
            release  => "${::lsbdistcodename}-wikimedia",
            repos    => 'component/puppetdb4',
            key      => 'B8A2DF05748F9D524A3A2ADE9D392D3FFADF18FB',
            notify   => Exec['apt_update_puppetdb'],
        }

        # First installs can trip without this
        exec {'apt_update_puppetdb':
            command     => '/usr/bin/apt-get update',
            refreshonly => true,
            logoutput   => true,
        }
    }

    package { 'puppetdb':
        ensure  => present,
        require => Apt::Source['puppetdb_apt'],
    }

    package { 'puppetdb-termini':
        ensure   => present,
        require => Apt::Source['ppuppetdb_apt'],
    }

    # Symlink /etc/puppetdb to /etc/puppetlabs/puppetdb
    file { '/etc/puppetdb':
        ensure => link,
        target => '/etc/puppetlabs/puppetdb',
    }
 
     file { '/var/lib/puppetdb':
         ensure => directory,
         owner  => 'puppetdb',
         group  => 'puppetdb',
     }

     file { '/etc/default/puppetdb':
         ensure  => present,
         owner   => 'root',
         group   => 'root',
         content => template('puppetdb/puppetdb.erb'),
     }

    ## Configuration

    file { '/etc/puppetdb/conf.d':
        ensure  => directory,
        owner   => 'puppetdb',
        group   => 'puppetdb',
        mode    => '0750',
        recurse => true,
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
        'node-purge-ttl' => '1d',
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

    puppetdb::config { 'command-processing':
        settings => {
            'threads' => $command_processing_threads,
        },
    }

    package { 'policykit-1':
        ensure => present,
    }

    service { 'puppetdb':
        ensure  => running,
    }

    ufw::allow { 'puppetdb':
        proto => 'tcp',
        port  => 8081,
    }
}
