# The port(s) can be configured as a single port, or an array of ports for a
# service/client that needs more than one discrete port covered by a single
# rule.
type Nftables::Port = Variant[
    Array[Stdlib::Port],
    Stdlib::Port,
    Pattern[/\A(?:[0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])\z/],
]
