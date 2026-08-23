# Which backend, or backends, a host's packet filtering uses.
#
# 'both' is a Miraheze addition on top of what Wikimedia's operations-puppet
# does. Their firewall module only ever runs one backend at a time and
# relies on every host's rules being equivalent across both backends for
# cross-host reachability during a migration; there's deliberately no
# Puppet-driven dual-run state. Since firewall::service and firewall::client
# already declare both backends' resources unconditionally either way,
# supporting 'both' here is just a matter of also ensure=>present-ing both
# ferm and nftables at once, which gives an actual window to verify nftables
# is enforcing the same rules as ferm before dropping ferm on that host.
type Firewall::Provider = Enum['none', 'ferm', 'nftables', 'both']
