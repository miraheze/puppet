# The port(s) can be configured as a single port, or an array of ports for a
# service/client that needs more than one discrete port covered by a single
# rule.
#
# A single port accepts a real Integer or a numeric String, since most of
# the existing codebase already writes port => '80' rather than port => 80,
# and there was no reason to force a mechanical rename across every one of
# those call sites just to gain type safety here. An array of ports is new,
# nothing uses it yet, so array elements are strict Stdlib::Port rather than
# also permitting the string form, to avoid carrying that convention into
# new code.
type Nftables::Port = Variant[
    Array[Stdlib::Port],
    Stdlib::Port,
    Pattern[/\A(?:[0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])\z/],
]
