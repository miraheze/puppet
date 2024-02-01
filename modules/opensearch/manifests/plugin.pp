# This define allows you to install arbitrary Opensearch plugins
# either by using the default repositories or by specifying an URL
#
# @example installation using a custom URL
#   opensearch::plugin { 'opensearch-jetty':
#    module_dir => 'opensearch-jetty',
#    url        => 'https://oss-es-plugins.s3.amazonaws.com/opensearch-jetty/opensearch-jetty-0.90.0.zip',
#   }
#
# @param ensure
#   Whether the plugin will be installed or removed.
#   Set to 'absent' to ensure a plugin is not installed
#
# @param configdir
#   Path to the opensearch configuration directory (OPENSEARCH_PATH_CONF)
#   to which the plugin should be installed.
#
# @param java_opts
#   Array of Java options to be passed to `OPENSEARCH_JAVA_OPTS`
#
# @param java_home
#   Path to JAVA_HOME, if Java is installed in a non-standard location.
#
# @param module_dir
#   Directory name where the module has been installed
#   This is automatically generated based on the module name
#   Specify a value here to override the auto generated value
#
# @param proxy_host
#   Proxy host to use when installing the plugin
#
# @param proxy_password
#   Proxy auth password to use when installing the plugin
#
# @param proxy_port
#   Proxy port to use when installing the plugin
#
# @param proxy_username
#   Proxy auth username to use when installing the plugin
#
# @param source
#   Specify the source of the plugin.
#   This will copy over the plugin to the node and use it for installation.
#   Useful for offline installation
#
# @param url
#   Specify an URL where to download the plugin from.
#
# @author Richard Pijnenburg <richard.pijnenburg@elasticsearch.com>
# @author Matteo Sessa <matteo.sessa@catchoftheday.com.au>
# @author Dennis Konert <dkonert@gmail.com>
# @author Tyler Langlois <tyler.langlois@elastic.co>
# @author Gavin Williams <gavin.williams@elastic.co>
#
define opensearch::plugin (
  Enum['absent', 'present']      $ensure         = 'present',
  Stdlib::Absolutepath           $configdir      = $opensearch::configdir,
  Array[String]                  $java_opts      = [],
  Optional[Stdlib::Absolutepath] $java_home      = undef,
  Optional[String]               $module_dir     = undef,
  Optional[String]               $proxy_host     = undef,
  Optional[String]               $proxy_password = undef,
  Optional[Integer[0, 65535]]    $proxy_port     = undef,
  Optional[String]               $proxy_username = undef,
  Optional[String]               $source         = undef,
  Optional[Stdlib::HTTPUrl]      $url            = undef,
) {
  include opensearch

  case $ensure {
    'present': {
      $_file_ensure = 'directory'
      $_file_before = []
    }
    'absent': {
      $_file_ensure = $ensure
      $_file_before = File[$opensearch::real_plugindir]
    }
    default: {
    }
  }

  # set proxy by override or parse and use proxy_url from
  # opensearch::proxy_url or use no proxy at all

  if ($proxy_host != undef and $proxy_port != undef) {
    if ($proxy_username != undef and $proxy_password != undef) {
      $_proxy_auth = "${proxy_username}:${proxy_password}@"
    } else {
      $_proxy_auth = undef
    }
    $_proxy = "http://${_proxy_auth}${proxy_host}:${proxy_port}"
  } elsif ($opensearch::proxy_url != undef) {
    $_proxy = $opensearch::proxy_url
  } else {
    $_proxy = undef
  }

  if ($source != undef) {
    $filename_array = split($source, '/')
    $basefilename = $filename_array[-1]

    $file_source = "${opensearch::package_dir}/${basefilename}"

    file { $file_source:
      ensure => 'file',
      source => $source,
      before => Opensearch_plugin[$name],
    }
  } else {
    $file_source = undef
  }

  $_module_dir = os_plugin_name($module_dir, $name)

  opensearch_plugin { $name:
    ensure                  => $ensure,
    configdir               => $configdir,
    opensearch_package_name => 'opensearch',
    java_opts               => $java_opts,
    java_home               => $java_home,
    source                  => $file_source,
    url                     => $url,
    proxy                   => $_proxy,
    plugin_dir              => $opensearch::real_plugindir,
    plugin_path             => $module_dir,
    before                  => Service[$opensearch::service_name],
  }
  -> file { "${opensearch::real_plugindir}/${_module_dir}":
    ensure  => $_file_ensure,
    mode    => 'o+Xr',
    recurse => true,
    before  => $_file_before,
  }

  if $opensearch::restart_plugin_change {
    Opensearch_plugin[$name] {
      notify +> Service[$opensearch::service_name],
    }
  }
}
