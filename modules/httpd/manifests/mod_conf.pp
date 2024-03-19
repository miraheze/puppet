# SPDX-License-Identifier: Apache-2.0
# == Define: httpd::mod_conf
#
# Custom resource for managing the configuration of Apache modules.
#
# === Parameters
#
# [*mod*]
#   Module name. Defaults to the resource title.
#
# [*loadfile*]
#   The .load config file that Puppet should manage.
#   Defaults to the resource title plus a '.load' suffix.
#
define httpd::mod_conf (
    VMlib::Ensure $ensure   = present,
    String        $mod      = $title,
    String        $loadfile = "${title}.load",
)
{
    stdlib::ensure_packages('apache2')

    if $ensure == present {
        exec { "ensure_${ensure}_mod_${mod}":
            command => "/usr/sbin/a2enmod ${mod}",
            creates => "/etc/apache2/mods-enabled/${loadfile}",
            notify  => Service['apache2'],
            require => Package['apache2'],
        }
    } else {
        exec { "ensure_${ensure}_mod_${mod}":
            command => "/usr/sbin/a2dismod -f ${mod}",
            onlyif  => "/usr/bin/test -L /etc/apache2/mods-enabled/${loadfile}",
            notify  => Service['apache2'],
            require => Package['apache2'],
        }
    }
}
