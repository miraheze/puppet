# === Class mediawiki::jobrunner
#
# Defines a jobrunner process for jobrunner selected machine only.
class mediawiki::jobrunner {
    $port = 9005
    $local_only_port = 9006
    $php_fpm_sock = 'php/fpm-www.sock'

    class { 'httpd':
        period  => 'daily',
        rotate  => 7,
        modules => [
            'alias',
            'authz_host',
            'autoindex',
            'deflate',
            'dir',
            'expires',
            'headers',
            'mime',
            'rewrite',
            'setenvif',
            'proxy_fcgi',
        ]
    }
    systemd::unit { 'apache2':
        content  => "[Service]\nCPUAccounting=yes\n",
        override => true,
    }

    # MPM configuration
    $threads_per_child = 25
    $apache_server_limit = $facts['processors']['count']
    $max_workers = $threads_per_child * $apache_server_limit
    if $workers_limit and is_integer($workers_limit) {
        $max_req_workers = min($workers_limit, $max_workers)
    }
    else {
        # Default if no override has been defined
        $max_req_workers = $max_workers
    }

    httpd::conf { 'worker':
        content => template('mediawiki/apache/worker.conf.erb')
    }

    class { 'httpd::mpm':
        mpm => 'worker',
    }

    file { '/etc/apache2/apache2.conf':
        content => template('mediawiki/apache/apache2.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        before  => Service['apache2'],
        require => Package['apache2'],
    }

    file { '/var/lock/apache2':
        ensure => directory,
        owner  => 'www-data',
        group  => 'root',
        mode   => '0755',
        before => File['/etc/apache2/apache2.conf'],
    }

    # Modules we don't enable.
    httpd::mod_conf { [
        'auth_basic',
        'authn_file',
        'authz_default',
        'authz_groupfile',
        'authz_user',
        'cgi',
        'deflate',
        'env',
        'negotiation',
        'reqtimeout',
    ]:
        ensure => absent,
    }

    file { '/srv/mediawiki/rpc':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/rpc',
        owner   => 'www-data',
        group   => 'www-data',
        require => File['/srv/mediawiki/config'],
    }

    httpd::conf { 'jobrunner_port':
        ensure   => present,
        priority => 1,
        content  => inline_template("# This file is managed by Puppet\nListen <%= @port %>\nListen <%= @local_only_port %>\n"),
    }

    httpd::site { 'jobrunner':
        priority => 1,
        content  => template('mediawiki/jobrunner.conf.erb'),
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Changeprop]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'jobrunner-9005':
        proto   => 'tcp',
        port    => '9005',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }
    ferm::service { 'jobrunner-9006':
        proto   => 'tcp',
        port    => '9006',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }
}
