# @summary
#   Configures the Icinga 2 feature elasticsearch.
#
# @example
#   class { 'icinga2::feature::elasticsearch':
#     host     => "10.10.0.15",
#     index    => "icinga2"
#   }
#
# @param ensure
#   Set to present enables the feature elasticsearch, absent disables it.
#
# @param host
#    Elasticsearch host address.
#
# @param port
#    Elasticsearch HTTP port.
#
# @param index
#    Elasticsearch index name.
#
# @param username
#    Elasticsearch user name.
#
# @param password
#    Elasticsearch user password. The password parameter isn't parsed anymore.
#
# @param enable_ssl
#    Either enable or disable SSL. Other SSL parameters are only affected if this is set to 'true'.
#
# @param ssl_noverify
#     Disable TLS peer verification.
#
# @param ssl_key_path
#   Location of the private key.
#
# @param ssl_cert_path
#   Location of the certificate.
#
# @param ssl_cacert_path
#   Location of the CA certificate.
#
# @param ssl_key
#   The private key in a base64 encoded string to store in spicified ssl_key_path file.
#
# @param ssl_cert
#   The certificate in a base64 encoded to store in spicified ssl_cert_path file.
#
# @param ssl_cacert
#   The CA root certificate in a base64 encoded string to store in spicified ssl_cacert_path file.
#
# @param enable_send_perfdata
#   Whether to send check performance data metrics.
#
# @param flush_interval
#   How long to buffer data points before transferring to Elasticsearch.
#
# @param flush_threshold
#   How many data points to buffer before forcing a transfer to Elasticsearch.
#
# @param enable_ha
#   Enable the high availability functionality. Only valid in a cluster setup.
#
class icinga2::feature::elasticsearch(
  Enum['absent', 'present']                     $ensure               = present,
  Optional[Stdlib::Host]                        $host                 = undef,
  Optional[Stdlib::Port::Unprivileged]          $port                 = undef,
  Optional[String]                              $index                = undef,
  Optional[String]                              $username             = undef,
  Optional[Variant[String, Sensitive[String]]]  $password             = undef,
  Optional[Boolean]                             $enable_ssl           = undef,
  Optional[Boolean]                             $ssl_noverify         = undef,
  Optional[Stdlib::Absolutepath]                $ssl_key_path         = undef,
  Optional[Stdlib::Absolutepath]                $ssl_cert_path        = undef,
  Optional[Stdlib::Absolutepath]                $ssl_cacert_path      = undef,
  Optional[Stdlib::Base64]                      $ssl_key              = undef,
  Optional[Stdlib::Base64]                      $ssl_cert             = undef,
  Optional[Stdlib::Base64]                      $ssl_cacert           = undef,
  Optional[Boolean]                             $enable_send_perfdata = undef,
  Optional[Icinga2::Interval]                   $flush_interval       = undef,
  Optional[Integer]                             $flush_threshold      = undef,
  Optional[Boolean]                             $enable_ha            = undef,
) {

  if ! defined(Class['::icinga2']) {
    fail('You must include the icinga2 base class before using any icinga2 feature class!')
  }

  $user          = $::icinga2::globals::user
  $group         = $::icinga2::globals::group
  $conf_dir      = $::icinga2::globals::conf_dir
  $_notify       = $ensure ? {
    'present' => Class['::icinga2::service'],
    default   => undef,
  }

  File {
    owner   => $user,
    group   => $group,
  }

  if $enable_ssl {

    $ssl_dir       = $::icinga2::globals::cert_dir
    $_ssl_key_mode = '0600'

    # Set defaults for certificate stuff and/or do validation
    if $ssl_key {
      if $ssl_key_path {
        $_ssl_key_path = $ssl_key_path }
      else {
        $_ssl_key_path = "${ssl_dir}/ElasticsearchWriter_elasticsearch.key"
      }

      $_ssl_key = $ssl_key

      file { $_ssl_key_path:
        ensure    => file,
        mode      => $_ssl_key_mode,
        content   => $_ssl_key,
        show_diff => false,
        tag       => 'icinga2::config::file',
      }
    } else {
      $_ssl_key_path = $ssl_key_path
    }

    if $ssl_cert {
      if $ssl_cert_path {
        $_ssl_cert_path = $ssl_cert_path }
      else {
        $_ssl_cert_path = "${ssl_dir}/ElasticsearchWriter_elasticsearch.crt"
      }

      $_ssl_cert = $ssl_cert

      file { $_ssl_cert_path:
        ensure  => file,
        content => $_ssl_cert,
        tag     => 'icinga2::config::file',
      }
    } else {
      $_ssl_cert_path = $ssl_cert_path
    }

    if $ssl_cacert {
      if $ssl_cacert_path {
        $_ssl_cacert_path = $ssl_cacert_path }
      else {
        $_ssl_cacert_path = "${ssl_dir}/ElasticsearchWriter_elasticsearch_ca.crt"
      }

      $_ssl_cacert = $ssl_cacert

      file { $_ssl_cacert_path:
        ensure  => file,
        content => $_ssl_cacert,
        tag     => 'icinga2::config::file',
      }
    } else {
      $_ssl_cacert_path = $ssl_cacert_path
    }

    $attrs_ssl = {
      enable_tls        => $enable_ssl,
      insecure_noverify => $ssl_noverify,
      ca_path           => $_ssl_cacert_path,
      cert_path         => $_ssl_cert_path,
      key_path          => $_ssl_key_path,
    }
  } # enable_ssl
  else {
    $attrs_ssl = { enable_tls  => $enable_ssl }
  }

  $_password = if $password =~ String {
    Sensitive($password)
  } elsif $password =~ Sensitive {
    $password
  } else {
    undef
  }

  $attrs = {
    host                   => $host,
    port                   => $port,
    index                  => $index,
    username               => $username,
    password               => $_password,
    enable_send_perfdata   => $enable_send_perfdata,
    flush_interval         => $flush_interval,
    flush_threshold        => $flush_threshold,
    enable_ha              => $enable_ha,
  }

  # create object
  icinga2::object { 'icinga2::object::ElasticsearchWriter::elasticsearch':
    object_name => 'elasticsearch',
    object_type => 'ElasticsearchWriter',
    attrs       => delete_undef_values($attrs + $attrs_ssl),
    attrs_list  => concat(keys($attrs), keys($attrs_ssl)),
    target      => "${conf_dir}/features-available/elasticsearch.conf",
    notify      => $_notify,
    order       => 10,
  }

  # import library 'perfdata'
  concat::fragment { 'icinga2::feature::elasticsearch':
    target  => "${conf_dir}/features-available/elasticsearch.conf",
    content => "library \"perfdata\"\n\n",
    order   => '05',
  }

  icinga2::feature { 'elasticsearch':
    ensure => $ensure,
  }
}
