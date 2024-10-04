# class: varnish
class varnish (
    String $cache_file_name = '/srv/varnish/cache_storage.bin',
    String $cache_file_size = '22G',
    Integer[1] $thread_pool_max = lookup('varnish::thread_pool_max'),
) {
    include varnish::nginx
    include prometheus::exporter::varnish

    stdlib::ensure_packages(['varnish', 'varnish-modules'])

    $vcl_reload_delay_s = max(2, ceiling(((100 * 5) + (100 * 4)) / 1000.0))
    $reload_vcl_opts = "-f /etc/varnish/default.vcl -d ${vcl_reload_delay_s} -a"

    file { '/usr/local/sbin/reload-vcl':
        source => 'puppet:///modules/varnish/varnish/reload-vcl.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
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
        options => 'noatime,defaults,size=256M',
        pass    => 0,
        dump    => 0,
        require => File['/var/lib/varnish'],
        notify  => Service['varnish'],
    }

    $module_path = get_module_path($module_name)
    $csp = loadyaml("${module_path}/data/csp.yaml")
    $backends = lookup('varnish::backends')
    $interval_check = lookup('varnish::interval-check')
    $interval_timeout = lookup('varnish::interval-timeout')

    $debug_access_key = lookup('passwords::varnish::debug_access_key')

    # (1024.0 * 1024.0) converts to megabytes.
    $mem_gb = $facts['memory']['system']['total_bytes'] / (1024.0 * 1024.0) / 1024.0
    if ($mem_gb < 90.0) {
        $v_mem_gb = 1
    } else {
        $v_mem_gb = ceiling(0.7 * ($mem_gb - 100.0))
    }

    file { '/etc/varnish/default.vcl':
        ensure  => present,
        content => template('varnish/default.vcl'),
        notify  => Exec['load-new-vcl-file'],
        require => Package['varnish'],
    }

    file { '/srv/varnish':
        ensure => directory,
        owner  => 'varnish',
        group  => 'varnish',
    }

    # TODO: On bigger memory hosts increase Transient size
    $storage = "-s file,${cache_file_name},${cache_file_size} -s Transient=malloc,${v_mem_gb}G"

    systemd::service { 'varnish':
        ensure         => present,
        content        => systemd_template('varnish'),
        service_params => {
            enable  => true,
            require => [
                Package['varnish'],
                File['/usr/local/sbin/reload-vcl'],
                File['/etc/varnish/default.vcl']
            ],
        }
    }

    systemd::service { 'varnishlog':
        ensure  => present,
        content => systemd_template('varnishlog'),
        restart => true,
        require => Service['varnish'],
    }

    service { 'varnishncsa':
        ensure  => 'stopped',
        require => Package['varnish'],
    }

    # Unfortunately, varnishlog can't log to syslog
    logrotate::conf { 'varnishlog_logs':
        ensure => present,
        source => 'puppet:///modules/varnish/varnish/varnishlog.logrotate.conf',
    }

    # This mechanism with the touch/rm conditionals in the pair of execs
    #   below should ensure that reload-vcl failures are retried on
    #   future puppet runs until they succeed.
    $vcl_failed_file = '/var/tmp/reload-vcl-failed'

    exec { 'load-new-vcl-file':
        require     => Service['varnish'],
        subscribe   => File['/etc/varnish/default.vcl'],
        command     => "/usr/local/sbin/reload-vcl ${reload_vcl_opts} || (touch ${vcl_failed_file}; false)",
        unless      => "test -f ${vcl_failed_file}",
        path        => '/bin:/usr/bin',
        refreshonly => true,
    }

    exec { 'retry-load-new-vcl-file':
        require => Exec['load-new-vcl-file'],
        command => "/usr/local/sbin/reload-vcl ${reload_vcl_opts} && (rm ${vcl_failed_file}; true)",
        onlyif  => "test -f ${vcl_failed_file}",
        path    => '/bin:/usr/bin',
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

    monitoring::nrpe { 'Varnish Backends':
        command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_varnishbackends'
    }

    monitoring::nrpe { 'HTTP 4xx/5xx ERROR Rate':
        command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_nginx_errorrate'
    }

    $backends.each | $name, $property | {
        monitoring::nrpe { "Nginx Backend for ${name}":
            command => "/usr/lib/nagios/plugins/check_tcp -H localhost -p ${property['port']}",
        }
    }
}
