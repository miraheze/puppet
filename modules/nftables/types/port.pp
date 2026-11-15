# The port(s) can be configured as a single port, or an array of ports for a
# service/client that needs more than one discrete port covered by a single
# rule. Both forms are strict Stdlib::Port (a real Integer), a single port
# expressed as a numeric string is no longer accepted here - every one of
# those call sites now goes through port_range instead, even when it's just
# expressing one port as [N, N].
type Nftables::Port = Variant[
    Array[Stdlib::Port],
    Stdlib::Port,
]
