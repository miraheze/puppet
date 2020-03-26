# MediaWiki apache config using hiera
class mediawiki::apache {

    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    $php_fpm_sock = 'php/fpm-www.sock'

    class { '::httpd':
        period              => 'daily',
        rotate              => '7',
        modules             => [
            'alias',
            'authz_host',
            'autoindex',
            'dir',
            'expires',
            'headers',
            'mime',
            'rewrite',
            'setenvif',
            'proxy_fcgi',
        ]
    }

    include ssl::wildcard
    include ssl::hiera

    # Modules we don't enable.
    # Note that deflate and filter are activated deep down in the
    # apache sites, we should probably move them here
    ::httpd::mod_conf { [
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

    file { '/etc/apache2/mods-available/expires.conf':
        ensure => present,
        source => 'puppet:///modules/mediawiki/apache/modules/expires.conf',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        notify => Service['apache2'],
    }

    file { '/etc/apache2/mods-available/autoindex.conf':
        ensure => present,
        source => 'puppet:///modules/mediawiki/apache/modules/autoindex.conf',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        notify => Service['apache2'],
    }


    file { '/etc/apache2/mods-available/setenvif.conf':
        ensure => present,
        source => 'puppet:///modules/mediawiki/apache/modules/setenvif.conf',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        notify => Service['apache2'],
    }

    file { '/etc/apache2/mods-available/mime.conf':
        ensure => present,
        source => 'puppet:///modules/mediawiki/apache/modules/mime.conf',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        notify => Service['apache2'],
    }

    # Add headers lost by mod_proxy_fastcgi
    ::httpd::conf { 'fcgi_headers':
        source   => 'puppet:///modules/mediawiki/apache/configs/fcgi_headers.conf',
        priority => 0,
    }

    # MPM configuration
    $threads_per_child = 25
    $apache_server_limit = $::processorcount
    $max_workers = $threads_per_child * $apache_server_limit
    if $workers_limit and is_integer($workers_limit) {
        $max_req_workers = min($workers_limit, $max_workers)
    }
    else {
        # Default if no override has been defined
        $max_req_workers = $max_workers
    }

    ::httpd::conf { 'worker':
        content => template('mediawiki/apache/worker.conf.erb')
    }

    class { '::httpd::mpm':
        mpm => 'worker'
    }

    file { '/etc/apache2/apache2.conf':
        content => template('mediawiki/apache/apache2.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        before  => Service['apache2'],
        require => Package['apache2'],
    }
}
