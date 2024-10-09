# == Class: haproxy
#
# === Parameters
#
# [*config_content*]
#   Content used to populate /etc/haproxy/haproxy.cfg. If not provided a default template
#   located on haproxy/haproxy.cfg.erb is used

class haproxy (
    Optional[String] $config_content  = undef,
) {

    package { [
        'socat',
        'haproxy',
    ]:
        ensure => present,
    }

    # /etc/haproxy is created by installing the haproxy package.
    # however manging ig in puppet means we can drop files into this directory
    # and not have to worry about dependencies as file objects get an auto require
    # for any managed parents directories
    file { ['/etc/haproxy', '/etc/haproxy/conf.d']:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/etc/haproxy/haproxy.cfg':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => $config_content,
        notify  => Service['haproxy'],
    }

    file { '/etc/default/haproxy':
        ensure  => present,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('haproxy/haproxy.default.erb'),
        notify  => Service['haproxy'],
    }

    service { 'haproxy':
        ensure  => 'running',
        enable  => true,
        restart => '/bin/systemctl reload haproxy.service',
    }
}
