# === Class mediawiki::dbhealth
class mediawiki::dbhealth (
    Hash[String, String] $sections = lookup('mediawiki::dbhealth::sections', {'default_value' => {
        'DEFAULT' => '10.0.19.170:3306',
        'c1'      => '10.0.15.110:3306',
        'c2'      => '10.0.16.128:3306',
        'c3'      => '10.0.17.119:3306',
        'c4'      => '10.0.18.102:3306',
        's1'      => '10.0.19.170:3306',
    }}),
    String $user                          = lookup('mediawiki::dbhealth::user', {'default_value' => 'mediawiki2024'}),
    Integer $interval                     = lookup('mediawiki::dbhealth::interval', {'default_value' => 2}),
    Integer $connect_timeout              = lookup('mediawiki::dbhealth::connect_timeout', {'default_value' => 1}),
    Integer $read_timeout                 = lookup('mediawiki::dbhealth::read_timeout', {'default_value' => 1}),
    Integer $slow_ms                      = lookup('mediawiki::dbhealth::slow_ms', {'default_value' => 500}),
    Float $max_conn_ratio                 = lookup('mediawiki::dbhealth::max_conn_ratio', {'default_value' => 0.9}),
    Integer $max_threads_running          = lookup('mediawiki::dbhealth::max_threads_running', {'default_value' => 0}),
    Integer $down_after                   = lookup('mediawiki::dbhealth::down_after', {'default_value' => 3}),
    Integer $up_after                     = lookup('mediawiki::dbhealth::up_after', {'default_value' => 10}),
    Integer $drain_query_seconds          = lookup('mediawiki::dbhealth::drain_query_seconds', {'default_value' => 30}),
    Integer $drain_max_threads_running    = lookup('mediawiki::dbhealth::drain_max_threads_running', {'default_value' => 8}),
    Integer $drain_timeout                = lookup('mediawiki::dbhealth::drain_timeout', {'default_value' => 900}),
    Integer $kill_after                   = lookup('mediawiki::dbhealth::kill_after', {'default_value' => 0}),
    Array[Array[Numeric, 2, 2]] $ramp     = lookup('mediawiki::dbhealth::ramp', {'default_value' => [[0, 0.1], [10, 0.5], [20, 1.0]]}),
) {
    file { '/usr/local/bin/mw-db-health':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/mw-db-health.php',
        notify => Service['mw-db-health'],
    }

    $config = {
        'private_settings'          => '/srv/mediawiki/config/PrivateSettings.php',
        'state_file'                => '/run/mw-db-health/state.json',
        'user'                      => $user,
        'interval'                  => $interval,
        'connect_timeout'           => $connect_timeout,
        'read_timeout'              => $read_timeout,
        'slow_ms'                   => $slow_ms,
        'max_conn_ratio'            => $max_conn_ratio,
        'max_threads_running'       => $max_threads_running,
        'down_after'                => $down_after,
        'up_after'                  => $up_after,
        'drain_query_seconds'       => $drain_query_seconds,
        'drain_max_threads_running' => $drain_max_threads_running,
        'drain_timeout'             => $drain_timeout,
        'kill_after'                => $kill_after,
        'ramp'                      => $ramp,
        'sections'                  => $sections,
    }

    file { '/etc/mw-db-health.json':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => epp('mediawiki/db-health.json.epp', { 'config' => $config }),
        notify  => Service['mw-db-health'],
    }

    systemd::service { 'mw-db-health':
        ensure  => present,
        content => systemd_template('mw-db-health'),
        restart => true,
        require => [
            File['/usr/local/bin/mw-db-health'],
            File['/etc/mw-db-health.json'],
            File['/srv/mediawiki/config/PrivateSettings.php'],
        ],
    }

    monitoring::nrpe { 'MediaWiki DB health probe':
        command => '/usr/lib/nagios/plugins/check_procs -a mw-db-health -c 1:1',
    }
}
