# == Class: trafficserver
#
# This module provisions Apache Traffic Server -- a fast, scalable caching
# proxy.
#
# === Logging
#
# ATS event logs can be written to ASCII files, binary files, or named pipes.
# Event logs are described here:
# https://docs.trafficserver.apache.org/en/latest/admin-guide/logging/understanding.en.html#event-logs
#
# === Parameters
#
# [*paths*]
#   Mapping of trafficserver paths. See Trafficserver::Paths and trafficserver::get_paths()
#
# [*http_port*]
#   Bind trafficserver to this TCP port for HTTP requests.
#
# [*https_port*]
#   Bind trafficserver to this TCP port for HTTPS requests.
#
# [*disable_dns_resolution*]
#   Disables (1) or enables (0) DNS resolution of hosts defined on remapping rules (default: 0)
#
# [*network_settings*]
#   Instance of Trafficserver::Network_settings. (default: undef).
#
# [*http_settings*]
#   Instance of Trafficserver::HTTP_settings. (default: undef).
#
# [*h2_settings*]
#   Instance of Trafficserver::H2_settings. (default: undef).
#
# [*ttfb_timeout*]
#   The timeout value (in seconds) for time to first byte for HTTP and HTTP2 connections. (default: 180 secs)
#
# [*inbound_tls_settings*]
#   Inbound TLS settings. (default: undef).
#   for example:
#   {
#       common => {
#           cipher_suite   => '-ALL:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384',
#           enable_tlsv1   => 0,
#           enable_tlsv1_1 => 0,
#           enable_tlsv1_2 => 1,
#           enable_tlsv1_3 => 1,
#       },
#       cert_path         => '/etc/ssl/localcerts',
#       cert_files        => ['globalsign-2018-ecdsa-unified.chained.crt','globalsign-2018-rsa-unified.chained.crt'],
#       private_key_path  => '/etc/ssl/private',
#       private_key_files => ['globalsign-2018-ecdsa-unified.key','globalsign-2018-rsa-unified.key'],
#       dhparams_file     => '/etc/ssl/dhparam.pem',
#       max_record_size   => 16383,
#   }
#
# [*outbound_tls_settings*]
#   Outbound TLS settings. (default: undef).
#   for example:
#   {
#       common => {
#           cipher_suite   => '-ALL:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384',
#           enable_tlsv1   => 0,
#           enable_tlsv1_1 => 0,
#           enable_tlsv1_2 => 1,
#           enable_tlsv1_3 => 1,
#       },
#       verify_origin   => true,
#       cacert_dirname  => '/etc/ssl/certs',
#       cacert_filename => 'Puppet_Internal_CA.pem',
#   }
# check the type definitions for more detailed information
#
# [*enable_xdebug*]
#   Enable the XDebug plugin. (default: false)
#   https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/xdebug.en.html
#
# [*enable_compress*]
#   Enable the compress plugin. (default: false)
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/compress.en.html
#
# [*collapsed_forwarding*]
#   Enable the Collapsed Forwarding plugin. (default: false)
#   https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/collapsed_forwarding.en.html
#
# [*origin_coalescing*]
#   Enable request coalescing for in-flight origin server requests. (default: true)
#
# [*max_lua_states*]
#   The maximum number of allowed Lua states. (default: 256).
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/plugins/lua.en.html
#
# [*mapping_rules*]
#   An array of Trafficserver::Mapping_rules, each representing a mapping rule. (default: []).
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/remap.config.en.html
#
# [*enable_caching*]
#   Enable caching of HTTP requests. (default: true)
#
# [*required_headers*]
#   The type of headers required in a request for the request to be cacheable.
#   (default: 2)
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/records.config.en.html
#
# [*guaranteed_max_lifetime*]
#   Maximum TTL of objects considered 'fresh' in seconds.
#   (default: 31536000)
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/records.config.en.html
#
# [*caching_rules*]
#   An array of Trafficserver::Caching_rules, each representing a caching rule. (default: undef).
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/cache.config.en.html
#
# [*negative_caching*]
#   Settings controlling whether or not Negative Response Caching should be
#   enabled, for which status codes, and the lifetime to apply to objects
#   without explicit Cache-Control or Expires. (default: undef).
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/records.config.en.html#negative-response-caching
#
# [*storage*]
#   An array of Trafficserver::Storage_elements. (default: undef).
#
#   Partitions can be specified by setting the 'devname' key, while files or
#   directories use 'pathname'. For example:
#
#     { 'devname'  => 'sda3' }
#     { 'pathname' => '/srv/storage/', 'size' => '10G' }
#
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/storage.config.en.html
#
# [*ram_cache_size*]
#   The amount of memory in bytes to reserve for RAM cache. Traffic Server
#   automatically determines the RAM cache size if this value is not specified
#   or set to -1. (default: -1)
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/records.config.en.html
#
# [*log_formats*]
#   An array of Trafficserver::Log_formats. (default: []).
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/logging.yaml.en.html
#
# [*log_filters*]
#   An array of Trafficserver::Log_filters. (default: []).
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/logging.yaml.en.html
#
# [*logs*]
#   An array of Trafficserver::Logs. (default: []).
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/files/logging.yaml.en.html
#
# [*parent_rules*]
#   An optional array of Trafficserver::Parent_Rule.
#   See https://docs.trafficserver.apache.org/en/8.0.x/admin-guide/files/parent.config.en.html and
#   the type definition (modules/trafficserver/types/parent_rule.pp) cause only a partial implementation
#   of parent rules is provided.
#
# [*error_page*]
#   A string containing the error page to deliver to clients when there are
#   problems with the HTTP transactions. (default: '<html><head><title>Error</title></head><body><p>Something went wrong</p></body></html>').
#   See https://docs.trafficserver.apache.org/en/latest/admin-guide/monitoring/error-messages.en.html#body-factory
#
# [*systemd_hardening*]
#   Whether or not to enable systemd unit security features. (default: true).
#
# [*res_track_memory*]
#   When enabled makes Traffic Server track memory usage (allocations and releases). (default: undef, behaves as 0)
#   Accepted values:
#   * 0 Memory tracking Disabled
#   * 1 Tracks IO Buffer Memory allocations and releases
#   * 2 Tracks IO Buffer Memory and OpenSSL Memory allocations and releases
#
# === Examples
#
#  trafficserver::instance { 'backend':
#    user          => 'trafficserver',
#    port          => 80,
#    log_mode      => 'ascii',
#    log_format    => 'squid',
#    log_filename  => 'access',
#    mapping_rules => [ { 'type'        => 'map',
#                         'target'      => 'http://grafana.wikimedia.org/',
#                         'replacement' => 'http://krypton.eqiad.wmnet/', },
#                       { 'type'        => 'map',
#                         'target'      => '/',
#                         'replacement' => 'http://deployment-mediawiki05.deployment-prep.eqiad1.wikimedia.cloud/' }, ],
#    caching_rules => [ { 'primary_destination' => 'dest_domain',
#                         'value'               => 'grafana.wikimedia.org',
#                         'action'              => 'never-cache' }, ],
#    storage       => [ { 'pathname' => '/srv/storage/', 'size' => '10G' },
#                       { 'devname'  => 'sda3', 'volume' => 1 },
#                       { 'devname'  => 'sdb3', 'volume' => 2, 'id' => 'cache.disk.1' }, ],
#  }
#
class trafficserver (
    Trafficserver::Paths $paths,
    Optional[Stdlib::Port] $http_port = undef,
    Optional[Stdlib::Port] $https_port = undef,
    Integer[0, 1] $disable_dns_resolution = 0,
    Optional[Trafficserver::Network_settings] $network_settings = undef,
    Optional[Trafficserver::HTTP_settings] $http_settings = undef,
    Optional[Trafficserver::H2_settings] $h2_settings = undef,
    Optional[Trafficserver::Inbound_TLS_settings] $inbound_tls_settings = undef,
    Optional[Trafficserver::Outbound_TLS_settings] $outbound_tls_settings = undef,
    Boolean $enable_xdebug = false,
    Boolean $enable_compress = false,
    Boolean $collapsed_forwarding = false,
    Boolean $origin_coalescing = true,
    Integer $max_lua_states = 256,
    Array[Trafficserver::Mapping_rule] $mapping_rules = [],
    Boolean $enable_caching = true,
    Optional[Integer[0,2]] $required_headers = undef,
    Integer $guaranteed_max_lifetime = 31536000,
    Optional[Array[Trafficserver::Caching_rule]] $caching_rules = undef,
    Optional[Trafficserver::Negative_Caching] $negative_caching = undef,
    Optional[Array[Trafficserver::Storage_element]] $storage = undef,
    Optional[Integer] $ram_cache_size = -1,
    Array[Trafficserver::Log_format] $log_formats = [],
    Array[Trafficserver::Log_filter] $log_filters = [],
    Array[Trafficserver::Log] $logs = [],
    Optional[Array[Trafficserver::Parent_rule]] $parent_rules = undef,
    String $error_page = '<html><head><title>Error</title></head><body><p>Something went wrong</p></body></html>',
    Boolean $systemd_hardening = true,
    Optional[Integer[0,2]] $res_track_memory = undef,
) {


    ## Packages
    package { ['trafficserver', 'trafficserver-experimental-plugins']:
        ensure  => present,
    }

    $user = 'trafficserver'  # needed by records.config.erb

    if !defined('$http_port') and !defined('$https_port') {
      fail('You need to specify at least one HTTP(S) port')
    }

    $error_template_path = "${paths['sysconfdir']}/error_template"
    file {
      [$error_template_path, "${error_template_path}/default"]:
        ensure  => directory,
        owner   => $trafficserver::user,
        mode    => '0755',
        require => Package['trafficserver'],
    }

    # needed by plugin.config.erb
    $compress_config_path = "${paths['sysconfdir']}/compress.config"

    # This is used to install the certificates in ssl_multicert.config
    $sslcerts = loadyaml('/etc/puppetlabs/puppet/ssl-cert/certs.yaml')
    # This is also used to redirect in the frontend
    $sslredirects = loadyaml('/etc/puppetlabs/puppet/ssl-cert/redirects.yaml')

    $mediawiki_ip = query_facts('Class[Role::Mediawiki]', ['ipaddress', 'ipaddress6'])

    ## Config files
    file {
        default:
          * => {
              owner   => $trafficserver::user,
              mode    => '0400',
              require => Package['trafficserver'],
              notify  => Service['trafficserver'],
          };

        $paths['records']:
          content => template('trafficserver/records.config.erb'),;

        "${paths['sysconfdir']}/remap.config":
          content => template('trafficserver/remap.config.erb'),;

        "${paths['sysconfdir']}/cache.config":
          content => template('trafficserver/cache.config.erb'),;

        "${paths['sysconfdir']}/ip_allow.config":
          content => template('trafficserver/ip_allow.config.erb'),;

        "${paths['sysconfdir']}/storage.config":
          content => template('trafficserver/storage.config.erb'),;

        "${paths['sysconfdir']}/plugin.config":
          content => template('trafficserver/plugin.config.erb'),;

        $paths['ssl_multicert']:
          content => template('trafficserver/ssl_multicert.config.erb'),;

        "${paths['sysconfdir']}/parent.config":
          content => template('trafficserver/parent.config.erb'),;

        "${paths['sysconfdir']}/logging.yaml":
          content => template('trafficserver/logging.yaml.erb');

        "${error_template_path}/default/.body_factory_info":
          # This file just needs to be there or ATS will refuse loading any
          # template
          content => '',
          require => File[$error_template_path];

        "${error_template_path}/default/default":
          content => $error_page,
          require => File[$error_template_path];
    }

    if $enable_compress {
        file { $compress_config_path:
            owner   => $trafficserver::user,
            mode    => '0400',
            require => Package['trafficserver'],
            notify  => Service['trafficserver'],
            content => template('trafficserver/compress.config.erb'),
        }
    }

    if $enable_caching and $storage {
        $storage.each |$value| {
            if $value['pathname'] {
                file { $value['pathname']:
                    ensure  => directory,
                    owner   => $trafficserver::user,
                    mode    => '0755',
                    require => Package['trafficserver'],
                    notify  => Service['trafficserver'],
                }
            }
        }
    }

    include ssl::wildcard
    include ssl::hiera

    ssl::cert { 'm.miraheze.org': }

    Class['ssl::wildcard'] ~> Service['trafficserver']
    Class['ssl::hiera'] ~> Service['trafficserver']
    Ssl::Cert['m.miraheze.org'] ~> Service['trafficserver']

    ## Service

    if ($http_port and $http_port < 1024) or ($https_port and $https_port < 1024) {
      $privileged_port = true
    } else {
      $privileged_port = false
    }

    systemd::service { 'trafficserver':
        content        => init_template('trafficserver', 'systemd_override'),
        override       => true,
        restart        => true,
        service_params => {
            restart => 'systemctl reload trafficserver',
            enable  => true,
        },
        subscribe      => Package[$trafficserver::packages],
    }
}
