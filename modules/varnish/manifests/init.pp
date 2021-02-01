# class: varnish
class varnish(
    String $cache_file_name = '/srv/varnish/cache_storage.bin',
    String $cache_file_size = '15G',
    Boolean $use_new_cache = false,
){
    include varnish::nginx
    include prometheus::varnish_prometheus_exporter

    package { [ 'varnish', 'stunnel4', 'varnish-modules' ]:
        ensure => present,
    }

    # Avoid race condition where varnish starts, before /var/lib/varnish was mounted as tmpfs
    file { '/var/lib/varnish':
        ensure  => directory,
        owner   => 'varnish',
        group   => 'varnish',
        require => Package['varnish'],
    }

    mount { '/var/lib/varnish':
        ensure  => mounted,
        device  => 'tmpfs',
        fstype  => 'tmpfs',
        options => 'noatime,defaults,size=128M',
        pass    => 0,
        dump    => 0,
        require => File['/var/lib/varnish'],
        notify  => Service['varnish'],
    }

    service { 'varnish':
        ensure  => 'running',
        require => Mount['/var/lib/varnish'],
    }

    service { 'stunnel4':
        ensure  => 'running',
        require => Package['stunnel4'],
    }
    
    $module_path = get_module_path($module_name)

    $csp_whitelist = loadyaml("${module_path}/data/csp_whitelist.yaml")
    $frame_whitelist = loadyaml("${module_path}/data/frame_whitelist.yaml")

    file { '/etc/varnish/default.vcl':
        ensure  => present,
        content => template('varnish/default.vcl'),
        notify  => Exec['varnish-server-syntax'],
        require => Package['varnish'],
    }

    file { '/srv/varnish':
        ensure  => directory,
        owner   => 'varnish',
        group   => 'varnish',
    }

    file { '/etc/default/varnish':
        ensure  => present,
        content => template('varnish/varnish.default.erb'),
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

    systemd::service { 'varnishlog':
        ensure  => present,
        content => systemd_template('varnishlog'),
        restart => true,
        require => Service['varnish'],
    }

    # Unfortunately, varnishlog can't log to syslog
    logrotate::conf { 'varnishlog_logs':
        ensure  => present,
        source  => 'puppet:///modules/varnish/varnish/varnishlog.logrotate.conf',
    }

    include ssl::wildcard
    include ssl::hiera

    ssl::cert { 'm.miraheze.org':
        notify => Service['nginx'],
    }

    Class['ssl::wildcard'] ~> Exec['nginx-syntax']
    Class['ssl::hiera'] ~> Exec['nginx-syntax']
    Ssl::Cert['m.miraheze.org'] ~> Exec['nginx-syntax']

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

    ['mon1', 'mw4', 'mw5', 'mw6', 'mw7', 'test2'].each |$host| {
        monitoring::services { "Stunnel Http for ${host}":
            check_command => 'nrpe',
            vars          => {
                nrpe_command => "check_stunnel_${host}",
                nrpe_timeout => '10s',
            },
        }
    }
}
