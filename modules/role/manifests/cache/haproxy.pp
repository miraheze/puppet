# role: cache::haproxy
# SPDX-License-Identifier: Apache-2.0
class role::cache::haproxy(
    Stdlib::Port $tls_port = lookup('role::cache::haproxy::tls_port'),
    Stdlib::Port $prometheus_port = lookup('role::cache::haproxy::prometheus_port', {'default_value'                                          => 9422}),
    Hash[String, String] $cache_backends = lookup('role::cache::haproxy::cache_backends'),
    Hash[String, Hash] $varnish_backends = lookup('role::cache::haproxy::varnish_backends'),
    Integer[0] $tls_cachesize = lookup('role::cache::haproxy::tls_cachesize'),
    Integer[0] $tls_session_lifetime = lookup('role::cache::haproxy::tls_session_lifetime'),
    Haproxy::Timeout $timeout = lookup('role::cache::haproxy::timeout'),
    Haproxy::H2settings $h2settings = lookup('role::cache::haproxy::h2settings'),
    Hash[String, Array[Haproxy::Var]] $vars = lookup('role::cache::haproxy::vars'),
    Hash[String, Array[Haproxy::Acl]] $acls = lookup('role::cache::haproxy::acls'),
    Optional[Hash[String, Array[Haproxy::Header]]] $add_headers = lookup('role::cache::haproxy::add_headers',         {'default_value'        => undef}),
    Hash[String, Array[Haproxy::Header]] $del_headers = lookup('role::cache::haproxy::del_headers'),
    Optional[Hash[String, Array[Haproxy::Action]]] $pre_acl_actions = lookup('role::cache::haproxy::pre_acl_actions', {'default_value'        => undef}),
    Optional[Hash[String, Array[Haproxy::Action]]] $post_acl_actions = lookup('role::cache::haproxy::post_acl_actions', {'default_value'      => undef}),
    Optional[Array[Haproxy::Sticktable]] $sticktables = lookup('role::cache::haproxy::sticktables', {'default_value'                          => undef}),
    Boolean $http_disable_keepalive = lookup('role::cache::haproxy::http_disable_keepalive', {'default_value'                                 => false}),
    Boolean $do_systemd_hardening = lookup('role::cache::haproxy::do_systemd_hardening', {'default_value'                                     => false}),
    Boolean $enable_coredumps = lookup('role::cache::haproxy::enable_coredumps', {'default_value'                                             => false}),
    Optional[Stdlib::Port] $http_redirection_port = lookup('role::cache::haproxy::http_redirection_port', {'default_value'                    => 80}),
    Optional[Haproxy::Timeout] $redirection_timeout = lookup('role::cache::haproxy::redirection_timeout', {'default_value'                    => undef}),
    Optional[Array[Haproxy::Filter]] $filters = lookup('role::cache::haproxy::filters', {'default_value'                                      => undef}),
    Boolean $extended_logging = lookup('role::cache::haproxy::extended_logging', {'default_value'                                             => false}),
    Optional[Integer] $log_length = lookup('role::cache::haproxy::log_length', {'default_value'                                               => 8192}),
    Boolean $numa_networking = lookup('role::cache::haproxy::numa_networking', {'default_value'                                               => false}),
    Boolean $use_graylog = lookup('role::cache::haproxy::use_graylog', {'default_value'                                                       => false}),
) {

    $site_resource = Haproxy::Site['tls']

    # variable used inside HAProxy's systemd unit
    $pid = '/run/haproxy/haproxy.pid'

    # If numa_networking is turned on, use interface_primary for NUMA hinting,
    # otherwise use 'lo' for this purpose.  Assumes NUMA data has "lo" interface
    # mapped to all cpu cores in the non-NUMA case.  The numa_iface variable is
    # in turn consumed by the systemd unit and config templates.
    if $numa_networking {
        $numa_iface = $facts['interface_primary']
    } else {
        $numa_iface = 'lo'
    }

    # used on haproxy.cfg.erb
    $socket = '/run/haproxy/haproxy.sock'

    # TODO: Under haproxy 3, support is better for seperated cert and key.
    # under 2.4+, you are limited to .key being prefixed to the cert name.
    if !defined(File['/etc/ssl/localcerts/miraheze-origin-cert.crt']) {
        file { '/etc/ssl/localcerts/miraheze-origin-cert.crt':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/miraheze-origin-cert.crt',
            notify => Service['haproxy'],
        }
    }
    if !defined(File['/etc/ssl/localcerts/miraheze-origin-cert.crt.key']) {
        file { '/etc/ssl/localcerts/miraheze-origin-cert.crt.key':
            ensure => 'present',
            source => 'puppet:///ssl-keys/miraheze-origin-cert.key',
            notify => Service['haproxy'],
        }
    }

    class { '::haproxy':
        config_content => template('role/cache/haproxy.cfg.erb'),
        systemd_content => template('role/cache/haproxy.service.erb'),
    }

    ensure_packages('python3-pystemd')
    file { '/usr/local/sbin/haproxy-stek-manager':
        ensure => present,
        source => 'puppet:///modules/role/cache/haproxy/haproxy_stek_manager.py',
        owner  => root,
        group  => root,
        mode   => '0544',
    }

    systemd::tmpfile { 'haproxy_secrets_tmpfile':
        content => 'd /run/haproxy-secrets 0700 haproxy haproxy -',
    }

    $tls_ticket_keys_path = '/run/haproxy-secrets/stek.keys'
    systemd::timer::job { 'haproxy_stek_job':
        ensure      => present,
        description => 'HAProxy STEK manager',
        command     => "/usr/local/sbin/haproxy-stek-manager ${tls_ticket_keys_path}",
        interval    => [
            {
            'start'    => 'OnCalendar',
            'interval' => '*-*-* 00/8:00:00', # every 8 hours
            },
            {
            'start'    => 'OnBootSec',
            'interval' => '0sec',
            },
        ],
        user        => 'root',
        require     => File['/usr/local/sbin/haproxy-stek-manager'],
    }

    mediawiki::errorpage { '/etc/haproxy/tls-terminator-tls-plaintext-error.html':
        ensure  => ($http_redirection_port != undef).bool2str('present', 'absent'),
        content => '<p>Insecure request forbidden, use HTTPS instead.</p>',
        before  => $site_resource,
    }

    $cloudflare_ipv4 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv4'), /[\r\n]/)
    $cloudflare_ipv6 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv6'), /[\r\n]/)
    $cloudflare_ips = $cloudflare_ipv4 + $cloudflare_ipv6

    haproxy::site { 'tls':
        ensure  => present,
        content => template('role/cache/haproxy/tls_terminator.cfg.erb'),
    }

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'HTTPS':
        check_command => 'check_curl',
        vars          => {
            address6         => $address,
            http_vhost       => $facts['networking']['fqdn'],
            http_ssl         => true,
            http_ignore_body => true,
            http_expect      => 'HTTP/2 404',
        },
    }

    monitoring::services { 'health.wikitide.net HTTPS':
        ensure        => present,
        check_command => 'check_curl',
        vars          => {
            address6         => $address,
            http_port        => 443,
            http_vhost       => 'health.wikitide.net',
            http_uri         => '/check',
            http_ssl         => true,
            http_ignore_body => true,
        },
    }

    $varnish_backends.each | $name, $property | {
        monitoring::nrpe { "Haproxy TLS backend for ${name}":
            command => "/usr/lib/nagios/plugins/check_tcp -H localhost -p ${property['port']}",
        }
    }

    rsyslog::conf { 'haproxy@tls':
        priority => 20,
        content  => template('role/cache/haproxy/haproxy.rsyslog.conf.erb'),
    }

    logrotate::conf { 'haproxy':
        ensure => present,
        source => 'puppet:///modules/role/cache/haproxy/logrotate',
    }

    $firewall_str = join(
        query_facts('Class[Prometheus]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['he-ipv6'] ) {
                "${value['networking']['ip']} ${value['networking']['interfaces']['he-ipv6']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
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
    ferm::service { "prometheus_${prometheus_port}":
        proto   => 'tcp',
        port    => $prometheus_port,
        srange  => "(${firewall_str})",
        notrack => true,
    }
}
