#  This define allows you to insert, update or delete Opensearch index
#  templates.
#
#  Template content should be defined through either the `content` parameter
#  (when passing a hash or json string) or the `source` parameter (when passing
#  the puppet file URI to a template json file).
#
# @param ensure
#   Controls whether the named index template should be present or absent in
#   the cluster.
#
# @param api_basic_auth_password
#   HTTP basic auth password to use when communicating over the Opensearch
#   API.
#
# @param api_basic_auth_username
#   HTTP basic auth username to use when communicating over the Opensearch
#   API.
#
# @param api_ca_file
#   Path to a CA file which will be used to validate server certs when
#   communicating with the Opensearch API over HTTPS.
#
# @param api_ca_path
#   Path to a directory with CA files which will be used to validate server
#   certs when communicating with the Opensearch API over HTTPS.
#
# @param api_host
#   Host name or IP address of the ES instance to connect to.
#
# @param api_port
#   Port number of the ES instance to connect to
#
# @param api_protocol
#   Protocol that should be used to connect to the Opensearch API.
#
# @param api_timeout
#   Timeout period (in seconds) for the Opensearch API.
#
# @param content
#   Contents of the template. Can be either a puppet hash or a string
#   containing JSON.
#
# @param source
#   Source path for the template file. Can be any value similar to `source`
#   values for `file` resources.
#
# @param validate_tls
#   Determines whether the validity of SSL/TLS certificates received from the
#   Opensearch API should be verified or ignored.
#
# @author Richard Pijnenburg <richard.pijnenburg@elasticsearch.com>
# @author Tyler Langlois <tyler.langlois@elastic.co>
#
define opensearch::template (
  Enum['absent', 'present']       $ensure                  = 'present',
  Optional[String]                $api_basic_auth_password = $opensearch::api_basic_auth_password,
  Optional[String]                $api_basic_auth_username = $opensearch::api_basic_auth_username,
  Optional[Stdlib::Absolutepath]  $api_ca_file             = $opensearch::api_ca_file,
  Optional[Stdlib::Absolutepath]  $api_ca_path             = $opensearch::api_ca_path,
  String                          $api_host                = $opensearch::api_host,
  Integer[0, 65535]               $api_port                = $opensearch::api_port,
  Enum['http', 'https']           $api_protocol            = $opensearch::api_protocol,
  Integer                         $api_timeout             = $opensearch::api_timeout,
  Optional[Variant[String, Hash]] $content                 = undef,
  Optional[String]                $source                  = undef,
  Boolean                         $validate_tls            = $opensearch::validate_tls,
) {
  if $content =~ String {
    $_content = parsejson($content)
  } else {
    $_content = $content
  }

  if $ensure == 'present' and $source == undef and $_content == undef {
    fail('one of "file" or "content" required.')
  } elsif $source != undef and $_content != undef {
    fail('"file" and "content" cannot be simultaneously defined.')
  }

  os_instance_conn_validator { "${name}-template":
    server  => $api_host,
    port    => $api_port,
    timeout => $api_timeout,
  }
  -> opensearch_template { $name:
    ensure       => $ensure,
    content      => $_content,
    source       => $source,
    protocol     => $api_protocol,
    host         => $api_host,
    port         => $api_port,
    timeout      => $api_timeout,
    username     => $api_basic_auth_username,
    password     => $api_basic_auth_password,
    ca_file      => $api_ca_file,
    ca_path      => $api_ca_path,
    validate_tls => $validate_tls,
  }
}
