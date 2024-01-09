# == Define prometheus::exporter::jmx
#
# Renders a Prometheus JMX Exporter config file.
#
# Parameters:
#
#  [*port*]
#    Port used by the exporter for the listen socket.
#
#  [*config_file*]
#    The full path of the configuration file to create. Check 'config_dir' for
#    more info about how its parent directory is handled.
#
# [*config_dir*]
#   The parent directory of the jmx exporter (usually /etc/prometheus). If not
#   undef or already defined, it will be created by this profile. This is only
#   a handy way to avoid code repetition while using this profile, but special
#   care must be taken since: 1) this parameter assumes a string like
#   '/etc/$name', arbitrary nesting is not currently supported 2) the $config_file
#   value needs to be set accordingly.
#   Default: undef
#
#  [*content*]
#    Content of the exporter's configuration file. One between content or source
#    must be specified.
#
#  [*source*]
#    Source content of the exporter's configuration file. One between content or
#    source must be specified.
#
# from https://github.com/wikimedia/puppet/blob/e652ddf8a73a946a84e006b7d33d2d0e3edd788e/modules/profile/manifests/prometheus/jmx_exporter.pp
define prometheus::exporter::jmx (
    Stdlib::Port               $port,
    Stdlib::Unixpath           $config_file,
    Optional[Stdlib::Unixpath] $config_dir = undef,
    Optional[String]           $content = undef,
    Optional[String]           $source  = undef,
) {
    if $source == undef and $content == undef {
        fail('you must provide either "source" or "content"')
    }

    if $source != undef and $content != undef  {
        fail('"source" and "content" are mutually exclusive')
    }

    if !defined(File['/usr/share/java/prometheus/jmx_prometheus_javaagent.jar']) {
        file { '/usr/share/java/prometheus':
            ensure => 'directory',
            owner  => 'root',
            group  => 'root',
        }

        file { '/usr/share/java/prometheus/jmx_prometheus_javaagent.jar':
            ensure  => 'present',
            mode    => '0555',
            owner   => 'root',
            group   => 'root',
            source  => 'puppet:///modules/prometheus/jmx_exporter/jmx_prometheus_javaagent.jar',
            require => File['/usr/share/java/prometheus']
        }
    }

    if $config_dir and ! defined(File[$config_dir]) {
        # Create the Prometheus JMX Exporter configuration's parent dir
        file { $config_dir:
            ensure => 'directory',
            mode   => '0444',
            owner  => 'root',
            group  => 'root',
        }
    }

    # Create the Prometheus JMX Exporter configuration
    file { $config_file:
        ensure  => 'present',
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => $content,
        source  => $source,
        # If the source is using a symlink, copy the link target, not the symlink.
        links   => 'follow',
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Prometheus]', ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { "prometheus ${port} jmx_exporter":
        proto  => 'tcp',
        port   => $port,
        srange => "(${firewall_rules_str})",
    }
}
