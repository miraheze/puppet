# == Define: httpd::site
#
# Manages Apache site configurations. This is a very thin wrapper around
# a File resource for a /etc/apache2/sites-available config file and a
# symlink pointing to it in /etc/apache/sites-enabled. By using it, you
# don't have to worry about dependencies and ordering; the resource will
# take care that Apache & all modules are provisioned before the site is.
#
# === Parameters
#
# [*ensure*]
#   If 'present', site will be enabled; if 'absent', disabled.
#   The default is 'present'.
#
# [*priority*]
#   If you need this site to load before or after other sites, you can
#   do so by manipulating this value. In most cases, the default value
#   of 50 should be fine.
#
# [*content*]
#   If defined, will be used as the content of the site configuration
#   file. Undefined by default. Mutually exclusive with 'source'.
#
# [*source*]
#   Path to file containing configuration directives. Undefined by
#   default. Mutually exclusive with 'content'.
#
# [*monitor*]
#
# === Examples
#
#  httpd::site { 'meta.miraheze.org':
#    ensure  => present,
#    content => template('meta/meta-miraheze-apache-config.erb'),
#  }
#
define httpd::site(
    Stdlib::Ensure $ensure   = 'present',
    Integer[0,99] $priority = 50,
    Optional[String] $content  = undef,
    Stdlib::Sourceurl $source   = undef,
    Boolean $monitor   = false,
) {

    httpd::conf { $name:
        ensure    => $ensure,
        conf_type => 'sites',
        priority  => $priority,
        content   => $content,
        source    => $source,
        monitor   => $monitor,
    }
}
