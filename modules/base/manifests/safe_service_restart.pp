# == define base::safe_service_restart
#
# Creates a safe service restart script for the titled resource.
#
# What this script will do:
# * Depool
# * Restart the service with name $title
# * Repool
#
# === Parameters
#
# If no pool is provided, or the realm is not production, the restart scripts will not use conftool
# and will just be a stub.
define base::safe_service_restart(
    Array[String] $varnish_pools
) {

    # This file will be created independently of the presence of pools to remove or not.
    file { "/usr/local/sbin/restart-${title}":
        ensure  => present,
        content => template('base/safe-restart.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
    }

}
