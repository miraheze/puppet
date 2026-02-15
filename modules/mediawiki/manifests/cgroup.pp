# === Class mediawiki::cgroup
class mediawiki::cgroup {
    stdlib::ensure_packages('cgroup-tools')

    systemd::service { 'cgroup':
        ensure  => absent,
        content => '',
        restart => false,
    }

    systemd::unit { 'mediawiki.slice':
        ensure  => present,
        content => systemd_template('cgroup'),
        restart => false,
    }
}
