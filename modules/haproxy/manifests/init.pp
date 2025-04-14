# == Class: haproxy
#
# === Parameters
#
# [*systemd_override*]
#   Override system-provided unit. Defaults to false
#
# [*systemd_content*]
#   Content used to create the systemd::service. If not provided a default template
#   located on haproxy/haproxy.service.erb is used
#
# [*config_content*]
#   Content used to populate /etc/haproxy/haproxy.cfg. If not provided a default template
#   located on haproxy/haproxy.cfg.erb is used

class haproxy(
    $template                         = 'haproxy/haproxy.cfg.erb',
    $socket                           = '/run/haproxy/haproxy.sock',
    $pid                              = '/run/haproxy/haproxy.pid',
    Boolean $systemd_override         = false,
    Optional[String] $systemd_content = undef,
    Optional[String] $config_content  = undef,
) {

    package { [
        'socat',
        'haproxy',
    ]:
        ensure => present,
    }

    if $socket == '/run/haproxy/haproxy.sock' or $pid == '/run/haproxy/haproxy.pid' {
        systemd::tmpfile { 'haproxy':
            content => 'd /run/haproxy 0775 root haproxy',
        }
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

    $haproxy_config_content = $config_content? {
        undef   => template($template),
        default => $config_content,
    }

    file { '/etc/haproxy/haproxy.cfg':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => $haproxy_config_content,
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

    $systemd_service_content = $systemd_content? {
        undef   => template('haproxy/haproxy.service.erb'),
        default => $systemd_content,
    }

    systemd::service { 'haproxy':
        override       => $systemd_override,
        content        => $systemd_service_content,
        service_params => {'restart' => '/bin/systemctl reload haproxy.service',}
    }
}
