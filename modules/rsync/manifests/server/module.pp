# Definition: rsync::server::module
#
# sets up a rsync server
#
# Parameters:
#   $path            - path to data
#   $comment         - rsync comment
#   $read_only       - yes||no, defaults to yes
#   $write_only      - yes||no, defaults to no
#   $list            - yes||no, defaults to yes
#   $uid             - uid of rsync server, defaults to 0
#   $gid             - gid of rsync server, defaults to 0
#   $incoming_chmod  - incoming file mode, defaults to 0644
#   $outgoing_chmod  - outgoing file mode, defaults to 0644
#   $max_connections - maximum number of simultaneous connections allowed, defaults to 0
#   $lock_file       - file used to support the max connections parameter, defaults to /var/run/rsyncd.lock
#    only needed if max_connections > 0
#   $secrets_file    - path to the file that contains the username:password pairs used for authenticating this module
#   $auth_users      - list of usernames that will be allowed to connect to this module (must be undef or an array)
#   $hosts_allow     - list of patterns allowed to connect to this module (man 5 rsyncd.conf for details, must be undef or an array)
#   $hosts_deny      - list of patterns allowed to connect to this module (man 5 rsyncd.conf for details, must be undef or an array)
#
#   sets up an rsync server
#
# Requires:
#   $path must be set
#
# Sample Usage:
#   # setup default rsync repository
#   rsync::server::module { 'repo':
#     path    => $base,
#     require => File[$base],
#   }
#
define rsync::server::module (
    String $path,
    Stdlib::Ensure $ensure          = present,
    String $comment         = undef,
    String $read_only       = 'yes',
    String $write_only      = 'no',
    String $list            = 'yes',
    String $uid             = '0',
    String $gid             = '0',
    String $incoming_chmod  = '0644',
    String $outgoing_chmod  = '0644',
    String $max_connections = '0',
    String $lock_file       = '/var/run/rsyncd.lock',
    Optional[String] $secrets_file    = undef,
    Optional[String] $auth_users      = undef,
    Optional[String] $hosts_allow     = undef,
    Optional[String] $hosts_deny      = undef
)  {

  file { "${rsync::server::rsync_fragments}/frag-${name}":
    ensure  => $ensure,
    content => template('rsync/module.erb'),
    notify  => Exec['compile fragments'],
  }
}
