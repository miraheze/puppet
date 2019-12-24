# class: varnish
class varnish {
    include varnish::nginx
    include prometheus::varnish_prometheus_exporter

    package { [ 'varnish', 'stunnel4', 'varnish-modules' ]:
        ensure => present,
    }

    service { 'varnish':
        ensure  => 'running',
        require => Package['varnish'],
    }

    service { 'stunnel4':
        ensure  => 'running',
        require => Package['stunnel4'],
    }

    file { '/var/lib/varnish/mediawiki':
        ensure  => directory,
        notify  => Exec['varnish-server-syntax'],
        require => Package['varnish'],
    }
    
    $module_path = get_module_path($module_name)

    $csp_whitelist = loadyaml("${module_path}/data/csp_whitelist.yaml")
    $frame_whitelist = loadyaml("${module_path}/data/frame_whitelist.yaml")
    $buster = os_version('debian == buster')

    file { '/etc/varnish/default.vcl':
        ensure  => present,
        content => template('varnish/default.vcl'),
        notify  => Exec['varnish-server-syntax'],
        require => Package['varnish'],
    }

    file { '/etc/default/varnish':
        ensure  => present,
        source  => 'puppet:///modules/varnish/varnish/varnish.default',
        notify  => Exec['varnish-server-syntax'],
        require => Package['varnish'],
    }

    exec { 'systemctl daemon-reload':
        path        => '/bin',
        refreshonly => true,
    }

    exec { 'varnish-server-syntax':
        command     => '/usr/sbin/varnishd -C -f /etc/varnish/default.vcl',
        notify      => Service['varnish'],
        refreshonly => true,
        require     => Exec['systemctl daemon-reload'],
    }

    file { '/etc/systemd/system/varnish.service':
        ensure  => present,
        source  => 'puppet:///modules/varnish/varnish/varnish.service',
        require => Package['varnish'],
        notify  => Exec['varnish-server-syntax'],
    }

    include ssl::wildcard
    include ssl::hiera

    file { '/etc/nginx/sites-enabled/default':
        ensure => absent,
        notify => Service['nginx'],
    }

    file { '/etc/default/stunnel4':
        ensure  => present,
        source  => 'puppet:///modules/varnish/stunnel/stunnel.default',
        notify  => Service['stunnel4'],
        require => Package['stunnel4'],
    }

    file { '/etc/stunnel/mediawiki.conf':
        ensure  => present,
        source  => 'puppet:///modules/varnish/stunnel/stunnel.conf',
        notify  => Service['stunnel4'],
        require => Package['stunnel4'],
    }

    file { '/usr/lib/nagios/plugins/check_varnishbackends':
        ensure => present,
        source => 'puppet:///modules/varnish/icinga/check_varnishbackends.py',
        mode   => '0755',
    }

    file { '/usr/lib/nagios/plugins/check_nginx_errorrate':
        ensure => present,
        source => 'puppet:///modules/varnish/icinga/check_nginx_errorrate',
        mode   => '0755',
    }

    # This script needs root access to read /etc/varnish/secret
    sudo::user { 'nrpe_sudo_checkvarnishbackends':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_varnishbackends' ],
    }

    # FIXME: Can't read access files without root
    sudo::user { 'nrpe_sudo_checknginxerrorrate':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_nginx_errorrate' ],
    }

    logrotate::conf { 'stunnel4':
        ensure => present,
        source => 'puppet:///modules/varnish/stunnel/stunnel4.logrotate.conf',
    }

    monitoring::services { 'Varnish Backends':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_varnishbackends',
        },
    }

    monitoring::services { 'HTTP 4xx/5xx ERROR Rate':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_nginx_errorrate',
        },
    }

    ['lizardfs6', 'misc2', 'mw1', 'mw2', 'mw3', 'test1'].each |$host| {
        monitoring::services { "Stunnel Http for ${host}":
            check_command => 'nrpe',
            vars          => {
                nrpe_command => "check_stunnel_${host}",
                nrpe_timeout => '10s',
            },
        }
    }
}
