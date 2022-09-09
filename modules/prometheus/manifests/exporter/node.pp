# Prometheus machine metrics exporter. See also
# https://github.com/prometheus/node_exporter
#
# This class will also setup the 'textfile' collector to read metrics from
# /var/lib/prometheus/node.d/*.prom. The directory is writable by members of
# unix group 'prometheus-node-exporter', see also
# https://github.com/prometheus/node_exporter#textfile-collector

# === Parameters
#
# [*$ignored_devices*]
#  Regular expression to exclude block devices from being reported
#
# [*$ignored_fs_types*]
#  Regular expression to exclude filesystem types from being reported
#
# [*$ignored_mount_points*]
#  Regular expression to exclude mount points from being reported
#
# [*$netstat_fields*]
#  Regular expression of netstat fields to include
#
# [*vmstat_fields*]
#  Regular expression of vmstat fields to include
#
# [*$collectors_extra*]
#  List of extra collectors to be enabled.
#
# [*$web_listen_address*]
#  IP:Port combination to listen on
#
#  Available collectors: https://github.com/prometheus/node_exporter/tree/v0.17.0#collectors
#
# From https://github.com/wikimedia/puppet/blob/2daf8fbd7151244e5f81608c077c07cf4ee71df5/modules/prometheus/manifests/node_exporter.pp

class prometheus::exporter::node (
    String $ignored_devices  = '^(ram|loop|fd|(h|s|v|xv)d[a-z]|nvme[0-9]+n[0-9]+p)[0-9]+$',
    String $ignored_fs_types  = '^(overlay|autofs|binfmt_misc|cgroup|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|mqueue|nsfs|proc|procfs|pstore|rpc_pipefs|securityfs|sysfs|tracefs)$',
    String $ignored_mount_points  = '^/(mnt|run|sys|proc|dev|var/lib/docker|var/lib/kubelet)($|/)',
    String $netstat_fields = '^(.*)',
    String $vmstat_fields = '^(.*)',
    Array[String] $collectors_extra = [],
    String $collector_ntp_server = '127.0.0.1',
    Pattern[/:\d+$/] $web_listen_address = ':9100',
) {
    $collectors_defaults = ['buddyinfo', 'conntrack', 'entropy', 'edac', 'filefd', 'filesystem', 'hwmon',
        'loadavg', 'mdadm', 'meminfo', 'netdev', 'netstat', 'sockstat', 'stat', 'tcpstat',
        'textfile', 'time', 'uname', 'vmstat']
    if $::virtual == 'kvm' {
        $collectors_default = concat($collectors_defaults, [ 'diskstats' ])
    } else {
        $collectors_default = $collectors_defaults
    }
    $textfile_directory = '/var/lib/prometheus/node.d'

    ensure_packages('prometheus-node-exporter')

    $collectors_enabled = concat($collectors_default, $collectors_extra)

    file { '/etc/default/prometheus-node-exporter':
          ensure  => present,
          mode    => '0444',
          owner   => 'root',
          group   => 'root',
          content => template('prometheus/etc/default/prometheus-node-exporter.erb'),
          notify  => Service['prometheus-node-exporter'],
    }

    # members of this group are able to publish metrics
    # via the 'textfile' collector by writing files to $textfile_directory.
    # prometheus-node-exporter will export all files matching *.prom
    group { 'prometheus-node-exporter':
        ensure => present,
    }

    file { $textfile_directory:
        ensure  => directory,
        mode    => '0770',
        owner   => 'prometheus',
        group   => 'prometheus-node-exporter',
        require => [Package['prometheus-node-exporter'],
                    Group['prometheus-node-exporter']],
    }

    service { 'prometheus-node-exporter':
        ensure  => running,
        enable  => true,
        require => Package['prometheus-node-exporter'],
    }

    $firewall_rules = query_facts('Class[Prometheus]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')

    ferm::service { 'prometheus node-exporter':
        proto  => 'tcp',
        port   => '9100',
        srange => "(${firewall_rules_str})",
    }
}
