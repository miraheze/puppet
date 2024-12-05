# === Class mediawiki::jobqueue::shared
#
# JobQueue resources for both runner & chron
class mediawiki::jobqueue::shared (
    String        $version,
    VMlib::Ensure $ensure = present,
) {
    $local_only_port = 9007
    $php_fpm_sock = 'php/fpm-www.sock'

    # Add headers lost by mod_proxy_fastcgi
    # The apache module doesn't pass along to the fastcgi appserver
    # a few headers, like Content-Type and Content-Length.
    # We need to add them back here.
    ::httpd::conf { 'fcgi_headers':
        ensure   => $ensure,
        source   => 'puppet:///modules/mediawiki/fcgi_headers.conf',
        priority => 0,
    }
    # Declare the proxies explicitly with retry=0
    httpd::conf { 'fcgi_proxies':
        ensure  => $ensure,
        content => template('mediawiki/fcgi_proxies.conf.erb')
    }

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
            'ssl',
            'proxy_fcgi',
        ]
    }

    class { 'httpd::mpm':
        ensure => $ensure,
        mpm    => 'worker',
    }

    # Modules we don't enable.
    httpd::mod_conf { [
        'authz_default',
        'authz_groupfile',
        'cgi',
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
        ensure   => $ensure,
        priority => 1,
        content  => inline_template("# This file is managed by Puppet\nListen <%= @local_only_port %>\n"),
    }

    httpd::conf { 'jobrunner_timeout':
        ensure   => $ensure,
        priority => 1,
        content  => inline_template("# This file is managed by Puppet\nTimeout 259200\n"),
    }

    httpd::site { 'jobrunner':
        priority => 1,
        content  => template('mediawiki/jobrunner_legacy.conf.erb'),
    }

    git::clone { 'JobRunner':
        ensure    => $ensure,
        directory => '/srv/jobrunner',
        origin    => 'https://github.com/miraheze/jobrunner-service',
        branch    => 'miraheze',
        owner     => 'www-data',
        group     => 'www-data',
    }

    $redis_password = lookup('passwords::redis::master')
    $redis_server_ip = lookup('mediawiki::jobqueue::runner::redis_ip', {'default_value' => false})

    file { '/srv/jobrunner/jobrunner.json':
        ensure  => $ensure,
        content => template('mediawiki/jobrunner.json.erb'),
        require => Git::Clone['JobRunner'],
    }

    file { '/srv/jobrunner/jobchron.json':
        ensure  => $ensure,
        content => template('mediawiki/jobchron.json.erb'),
        require => Git::Clone['JobRunner'],
    }
}
