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

    class { 'httpd::mpm':
        mpm => 'worker',
    }

    # Modules we don't enable.
    httpd::mod_conf { [
        'authz_default',
        'authz_groupfile',
        'cgi',
    ]:
        ensure => absent,
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
}