# Class: zookeeper::install::package
#
# This module manages package installation
#
# PRIVATE CLASS - do not use directly (use main `zookeeper` class).
class zookeeper::install::package inherits zookeeper::install {
  # Allow installing multiple packages, like zookeeper, zookeeper-bin etc.
  ensure_resource('package', $zookeeper::packages, { 'ensure' => $zookeeper::ensure })

  # Make sure, that service package was not installed earlier
  if ($zookeeper::service_provider == 'init.d' and (!member($zookeeper::packages, $zookeeper::service_package))) {
    package { [$zookeeper::service_package]: #init.d scripts for zookeeper
      ensure  => $zookeeper::ensure,
    }
  }
}
