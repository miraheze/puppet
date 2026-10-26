# Pools of servers balanced behind Varnish. The key is the pool name.
#
# port
#   Loopback port Varnish connects to for this pool
# default
#   Exactly one pool sets this. Requests that match no other pool go there
# agent
#   Set to false when the servers of this pool do not run the agent check.
#   A server can override this with lb_agent. Defaults to true
# url_regex
#   VCL regex matched against req.url to send a request to this pool
# host_regex
#   VCL regex matched against the Host header. Combined with url_regex using and
# check_uri, check_host, check_status, check_method
#   Health check sent to every server. Defaults to HEAD /check on
#   health.wikitide.net expecting 204
type Haproxy::Lbpools = Hash[Pattern[/\A[a-z][a-z0-9_]*\z/], Struct[{
    'port'                   => Stdlib::Port,
    Optional['default']      => Boolean,
    Optional['agent']        => Boolean,
    Optional['url_regex']    => String[1],
    Optional['host_regex']   => String[1],
    Optional['check_uri']    => String[1],
    Optional['check_host']   => String[1],
    Optional['check_status'] => Integer[100, 599],
    Optional['check_method'] => Enum['GET', 'HEAD'],
}]]
