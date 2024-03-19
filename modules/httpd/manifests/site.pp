# SPDX-License-Identifier: Apache-2.0
# == Define: httpd::site
#
# Manages Apache site configurations. This is a very thin wrapper around
# a File resource for a /etc/apache2/sites-available config file and a
# symlink pointing to it in /etc/apache/sites-enabled. By using it, you
# don't have to worry about dependencies and ordering; the resource will
# take care that all modules are provisioned before the site is.
# Note: you may need to include the httpd class, to ensure that that
# puppet notify in httpd::conf will work.
# Example:
# class { 'httpd':}
# httpd::site{ 'some-site':
#     content => template('some-site/apache-vhost.erb'),
# }
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
define httpd::site (
    VMlib::Ensure                $ensure   = 'present',
    Integer[0,99]                $priority = 50,
    Optional[String]             $content  = undef,
    Optional[Stdlib::Filesource] $source   = undef,
) {

    httpd::conf { $name:
        ensure    => $ensure,
        conf_type => 'sites',
        priority  => $priority,
        content   => $content,
        source    => $source,
    }
}
