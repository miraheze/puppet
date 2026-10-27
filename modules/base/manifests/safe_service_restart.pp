# == define base::safe_service_restart
#
# Creates a safe service restart script for the titled resource.
#
# What this script will do:
# * Depool the server from the load balancer pools on the cache hosts
# * Restart the service with name $title
# * Repool
define base::safe_service_restart(
    Array[String] $nodes,
) {

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Varnish' } or
    resources { type = 'Class' and title = 'Role::Cache::Varnish' })
    | PQL
    $cache_nodes = puppetdb::query_facts(
        ['networking'],
        $subquery
    ).values().map |$_facts| {
        $_facts['networking']['fqdn']
    }.flatten.sort.unique

    $totp_secret = lookup('passwords::varnish::varnish_totp_secret')

    # This file will be created independently of the presence of pools to remove or not.
    file { "/usr/local/sbin/restart-${title}":
        ensure  => present,
        content => template('base/safe-restart.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
    }

}
