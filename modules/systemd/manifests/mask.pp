# == systemd::mask ===
#
# @summary Use 'systemctl mask $title' to link the service unit file to /dev/null so
#          that the service cannot be started.
#
#
# Note that systemd::mask and systemd::unmask can be used to ensure that
# installing a package does not result in its service being automatically
# started. For example:
#
#  systemd::mask { 'mtail.service':
#      unless => '/usr/bin/dpkg -s mtail | /bin/grep -q "^Status: install ok installed$"',
#  }
#
#  package { 'mtail':
#      ensure  => present,
#      require => Systemd::Mask['mtail.service'],
#      notify  => Systemd::Unmask['mtail.service'],
#  }
#
#  systemd::unmask { 'mtail': }
# @param unit the unit name
# @param unless and unless clause to use
define systemd::mask (
    Systemd::Unit::Name $unit   = $title,
    Optional[String]    $unless = undef,
) {
    exec { "mask_${unit}":
        command => "/bin/systemctl mask ${unit}",
        creates => "/etc/systemd/system/${unit}",
        unless  => $unless,
    }
}