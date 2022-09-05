# == Class: puppetdb
#
# Sets up the puppetdb clojure app.
#
# === Parameters
#
# [*db_rw_host*] The read, write db hostname, eg db4.miraheze.org.
#
# [*jvm_opts*] Puppetdb java options, eg configuring heap.
#
# [*db_user*] The db user that puppetdb uses to connect to postgresql.
#
# [*perform_gc*] Weather to cleanup the db.
#
# [*command_processing_threads*] How mcuh concurrency to run puppetdb under, eg 2 threads.
#
# [*bind_ip*] The ip to bind to puppetdb, eg 0.0.0.0 which means any ip.
#
# [*db_ro_host*] The read only db hostname, eg db4.miraheze.org.
#
# [*db_password*] The db password for the postgresql db.
#
# [*db_ssl*] Weather to enable ssl connectivity to the postgresql db.
#
# [*puppet_major_version*] Which puppet version to use, eg 4.
#
class puppetdb(
    String $db_rw_host = lookup('puppetdb::db_rw_host', {'default_value' => 'localhost'}),
    String $puppetdb_jvm_opts = lookup('puppetdb::jvm_opts', {'default_value' =>'-Xmx1G'}),
    String $db_user = lookup('puppetdb::db_user', {'default_value' =>'puppetdb'}),
    Boolean $perform_gc = lookup('puppetdb::perform_gc', {'default_value' => true}),
    Integer $command_processing_threads = lookup('puppetdb::command_processing_threads', {'default_value' => 2}),
    Optional[String] $bind_ip = lookup('puppetdb::bind_ip', {'default_value' => '0.0.0.0'}),
    Optional[String] $db_ro_host = lookup('puppetdb::db_ro_host', {'default_value' => undef}),
    Optional[String] $db_password = lookup('puppetdb::db_password', {'default_value' => undef}),
    Boolean $db_ssl = lookup('puppetdb::db_ssl', {'default_value' => true}),
    Integer $puppet_major_version = lookup('puppet_major_version', {'default_value' => 6})
) {

    package { 'default-jdk':
        ensure => present,
    }

    ## PuppetDB installation

    package { 'puppetdb':
        ensure  => present,
        require => Apt::Source['puppetlabs'],
    }

    package { 'puppetdb-termini':
        ensure  => present,
        require => Apt::Source['puppetlabs'],
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

    $jvm_opts = "${puppetdb_jvm_opts} -javaagent:/usr/share/java/prometheus/jmx_prometheus_javaagent.jar=${::fqdn}:9401:/etc/puppetlabs/puppetdb/jvm_prometheus_jmx_exporter.yaml"
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
        $ssl = '?ssl=true&sslmode=require'
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
        'port'                      => 8080,
        'ssl-port'                  => 8081,
        'ssl-key'                   => '/etc/puppetlabs/puppetdb/ssl/private.pem',
        'ssl-cert'                  => '/etc/puppetlabs/puppetdb/ssl/public.pem',
        'ssl-ca-cert'               => '/etc/puppetlabs/puppetdb/ssl/ca.pem',
        'access-log-config'         => '/etc/puppetlabs/puppetdb/request-logging.xml',
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
        ensure => running,
        enable => true,
    }

    monitoring::services { 'puppetdb':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '8081',
        },
    }

    $firewall_rules = query_facts('Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'icinga access port 8081':
        proto  => 'tcp',
        port   => '8081',
        srange => "(${firewall_rules_str})",
    }
}
