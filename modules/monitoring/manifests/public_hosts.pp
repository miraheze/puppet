# class: monitoring::public_hosts
class monitoring::public_hosts (
    String $gateway,
) {
    $ips = vmlib::public_only_ipv4()
    if !$ips.empty {
        file { '/usr/local/sbin/monitoring-public-hosts-routes':
            ensure => present,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
            source => 'puppet:///modules/monitoring/public-hosts-routes.sh',
        }

        systemd::service { 'monitoring-public-hosts-routes':
            ensure  => present,
            restart => true,
            content => epp('monitoring/public-hosts-routes.service.epp', {
                'gateway' => $gateway,
                'ips'     => $ips,
            }),
            require => File['/usr/local/sbin/monitoring-public-hosts-routes'],
        }
    }
}
