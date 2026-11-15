# @summary
#   Manage the IcingaDB Redis server.
#
# @example Enable required repositories, bind Redis on Port `6380` (default) on localhost and increase keepalive and number of databases.
#   class { 'icingadb::redis':
#     manage_repos => true,
#     bind         => '127.0.0.1',
#     port         => 6380,
#     config       => {
#       tcp_keepalive => 400,
#       databases     => 8,
#     }
#   }
#
# @example Bind Redis to port 6380 an for encrypted connections to 6381 (default) on localhost and the main interface. Also force an authentication by password.
#   class { 'icingadb::redis':
#     bind             => ['127.0.0.1', $::ipaddress],
#     requirepass      => Sensitive('supersecret'),
#     use_tls          => true,
#     tls_port         => 6381,
#     tls_cert_file    => '/etc/icingadb-redis/server.crt',
#     tls_key_file     => '/etc/icingadb-redis/server.key',
#     tls_cacert_file  => '/etc/icingadb-redis/ca.crt',
#   }
#
# @example Bind Redis for encrypted only connections to 6380 on localhost and the main interface. Also force a valid client certificate for authentication. 
#   class { 'icingadb::redis':
#     bind             => ['127.0.0.1', $::ipaddress],
#     use_tls          => true,
#     tls_port         => 6380,
#     tls_cert_file    => '/etc/icingadb-redis/server.crt',
#     tls_key_file     => '/etc/icingadb-redis/server.key',
#     tls_cacert_file  => '/etc/icingadb-redis/ca.crt',
#     tls_auth_clients => 'yes',
#   }
#
# @param ensure
#   Choose wether the service is `running` or `stopped`.
#
# @param enable
#   Choose wether the service has to start at boot.
#
# @param bind
#   Configure which IP address(es) to listen on. To bind on
#   all interfaces, use an empty array.
#
# @param port
#   Configure which port to listen on.
#
# @param manage_repos
#   Whether to involve the Icinga repositories.
#
# @param manage_packages
#   Whether or not to manage the IcingaDB packages.
#
# @param requirepass
#   Require clients to issue AUTH <PASSWORD> before processing
#   any other commands.
#
# @param use_tls
#   Wether or not to enable tls encryption.
#
# @param tls_port
#   Configure which port to listen on for tls encrypted connection. Only valid if `use_tls` is turned on.
#
# @param tls_cert
#   Certificate in PEM format. Only valid if `use_tls` is turned on.
#
# @param tls_key
#   Private key in PEM format. Only valid if `use_tls` is turned on.
#
# @param tls_cacert
#   The CA root certificate in PEM format. Only valid if `use_tls` is turned on.
#
# @param tls_cert_file
#   Location of the certificate file. Only valid if `use_tls` is turned on.
#
#
# @param tls_key_file
#   Location of the private key file. Only valid if `use_tls` is turned on.
#
#
# @param tls_cacert_file
#   Location of the CA root certificate. Only valid if `use_tls` is turned on.
#
#
# @param tls_auth_clients
#   Set to `yes` to force authentication with a valid client certificate.
#   Other Options are `no` and `optional`. Only valid if `use_tls` is turned on.
#
# @param config
#   Other parameters that can be set, see redis::instance.
#
#
class icingadb::redis (
  Enum['running','stopped']                    $ensure           = 'running',
  Boolean                                      $enable           = true,
  Boolean                                      $manage_repos     = false,
  Boolean                                      $manage_packages  = true,
  Variant[Stdlib::Host,Array[Stdlib::Host]]    $bind             = ['127.0.0.1', '::1'],
  Stdlib::Port                                 $port             = 6380,
  Optional[Icinga::Secret]                     $requirepass      = undef,
  Optional[Boolean]                            $use_tls          = undef,
  Stdlib::Port                                 $tls_port         = 6381,
  Optional[String[1]]                          $tls_cert         = undef,
  Optional[Icinga::Secret]                     $tls_key          = undef,
  Optional[String[1]]                          $tls_cacert       = undef,
  Optional[Stdlib::Absolutepath]               $tls_cert_file    = undef,
  Optional[Stdlib::Absolutepath]               $tls_key_file     = undef,
  Optional[Stdlib::Absolutepath]               $tls_cacert_file  = undef,
  Optional[Enum['yes', 'no', 'optional']]      $tls_auth_clients = undef,
  Hash[String[1], Any]                         $config           = {},
) {
  require icingadb::redis::globals

  if $manage_repos {
    require icinga::repos
  }

  class { 'icingadb::redis::install': }
  -> class { 'icingadb::redis::config': }
  ~> class { 'icingadb::redis::service': }

  contain icingadb::redis::install
  contain icingadb::redis::config
  contain icingadb::redis::service
}
