# class: varnish
class varnish (
    String $cache_file_name = '/srv/varnish/cache_storage.bin',
    String $cache_file_size = '22G',
    Integer[1] $thread_pool_max = lookup('varnish::thread_pool_max'),
    Integer $transient_gb = lookup('varnish::transient_storage'),
    Hash $backends = lookup('varnish::backends'),
    Boolean $use_nginx = true,
) {
    if $use_nginx {
        include varnish::nginx
    }
    include prometheus::exporter::varnish

    stdlib::ensure_packages([
        'varnish',
        'varnish-modules',
        'python3-flask',
        'python3-pyotp',
        'gunicorn'
    ])

    file { '/opt/varnish-depool':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0700',
    }

    file { '/opt/varnish-depool/varnish-depool.py':
        ensure  => present,
        source  => 'puppet:///modules/varnish/varnish-depool.py',
        owner   => 'root',
        group   => 'root',
        mode    => '0700',
        notify  => Service['varnish-depool'],
        require => File['/opt/varnish-depool']
    }

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
        options => 'noatime,defaults,size=512M',
        pass    => 0,
        dump    => 0,
        require => File['/var/lib/varnish'],
        notify  => Service['varnish'],
    }

    $module_path = get_module_path('mediawiki')
    $csp = loadyaml("${module_path}/data/csp.yaml")
    $cloudflare_ipv4 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv4'), /[\r\n]/)
    $cloudflare_ipv6 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv6'), /[\r\n]/)
    $interval_check = lookup('varnish::interval-check')
    $interval_timeout = lookup('varnish::interval-timeout')

    $debug_access_key = lookup('passwords::varnish::debug_access_key')

    if $transient_gb > 0 {
        $transient_storage = "-s Transient=malloc,${transient_gb}G"
    } else {
        $transient_storage = ''
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
    $storage = "-s file,${cache_file_name},${cache_file_size} ${transient_storage}"

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

    $varnish_totp_secret = lookup('passwords::varnish::varnish_totp_secret')
    systemd::service { 'varnish-depool':
        ensure  => present,
        content => systemd_template('varnish-depool'),
        restart => true,
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

    if $use_nginx {
        monitoring::nrpe { 'HTTP 4xx/5xx ERROR Rate':
            command => '/usr/bin/sudo /usr/lib/nagios/plugins/check_nginx_errorrate'
        }
    }

    $backends.each | $name, $property | {
        monitoring::nrpe { "Nginx Backend for ${name}":
            command => "/usr/lib/nagios/plugins/check_tcp -H localhost -p ${property['port']}",
        }
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Icinga2] or Class[Role::Mediawiki] or Class[Role::Mediawiki_task]', ['networking'])
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
    ferm::service { "${facts['networking']['fqdn']} varnish depool service port 5001":
        proto  => 'tcp',
        port   => '5001',
        srange => "(${firewall_rules_str})",
    }

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'varnish-depool service':
        check_command => 'tcp',
        vars          => {
            tcp_address => $address,
            tcp_port    => '5001',
        },
    }
}
