# == define base::safe_service_restart
#
# Creates restart-${title}, which restarts the service with that name.
#
# On the servers in $nodes the script does this:
# * Set the server to maint in the pools of every cache host
# * Restart the service
# * Set the server back to ready
#
# === Parameters
#
# [*nodes*]
#   FQDNs of the servers that are in the cache host pools. Any other host
#   restarts the service directly. An empty list means every host.
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

    file { "/usr/local/sbin/restart-${title}":
        ensure  => present,
        content => template('base/safe-restart.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
    }

}
