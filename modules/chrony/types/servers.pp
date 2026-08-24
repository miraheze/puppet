# @summary Type for the `servers`, `pools` and `peers` parameters.
#
# This type is for the `servers`, `pools` and `peers` parameters.
#
# @example A hash of servers
#   {
#     'ntp1.example.com => [
#       'minpoll 3',
#       'maxpoll 6',
#     ],
#     'ntp2.example.com => [
#       'iburst',
#       'minpoll 4',
#       'maxpoll 8',
#     ],
#   }
#
# @example An array of servers
#   [
#     'ntp1.example.com',
#     'ntp2.example.com',
#   ]
type Chrony::Servers = Variant[
  Hash[Stdlib::Host, Optional[Array[String]]],
  Array[Stdlib::Host],
]
