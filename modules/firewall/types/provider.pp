# Which backend, or backends, a host's packet filtering uses.
type Firewall::Provider = Enum['none', 'ferm', 'nftables', 'both']
