# == Class systemd ==
#
# This class just defines a guard against running on non-systemd systems, and
# a few constants.
#
class systemd {
    # Directories for base units and overrides
    $base_dir = '/lib/systemd/system'
    $override_dir = '/etc/systemd/system'

    file { '/usr/local/bin/systemd-timer-mail-wrapper':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/systemd/systemd-timer-mail-wrapper.py',
    }
}
