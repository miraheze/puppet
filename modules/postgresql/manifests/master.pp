# Class: postgresql::master
#
# This class installs the server in a master configuration
#
# Parameters:
#   master_server
#       An FQDN. Defaults to $::fqdn. Should be the same as in slaves configured with this module
#   includes
#       An array of files to be included by the main configuration
#   pgversion
#       Defaults to 9.3 in Ubuntu Trusty and 9.4 in Debian jessie.
#   ensure
#       Defaults to present
#   max_wal_senders
#       Defaults to 5. Refer to postgresql documentation for its meaning
#   checkpoint_segments
#       Defaults to 64. Refer to postgresql documentation for its meaning
#   wal_keep_segments
#       Defaults to 128. Refer to postgresql documentation for its meaning
#   root_dir
#       See $postgresql::server::root_dir
#   use_ssl
#       Enable ssl
#   locale
#       Locale used to initialise posgresql cluster.
#       Setting the locale ensure that locale and encodings will be the same
#       whether $LANG and $LC_* are set or not.
#
# Actions:
#  Install/configure postgresql as a master. Also create replication users
#
# Requires:
#
# Sample Usage:
#  include postgresql::master

class postgresql::master(
    String $master_server = $facts['networking']['fqdn'],
    Optional[Array] $includes = [],
    String $pgversion = $facts['os']['distro']['codename'] ? {
        'bookworm' => '15',
        'bullseye' => '13',
        'buster'  => '11',
        'stretch' => '9.6',
        'jessie'  => '9.4',
    },
    VMlib::Ensure $ensure = 'present',
    Integer $max_wal_senders = 5,
    Integer $checkpoint_segments = 64,
    Integer $wal_keep_segments = 128,
    String $root_dir = '/var/lib/postgresql',
    Boolean $use_ssl=false,
    String $locale = 'en_US.UTF-8',
) {

    $data_dir = "${root_dir}/${pgversion}/main"

    class { '::postgresql::server':
        ensure    => $ensure,
        pgversion => $pgversion,
        includes  => [ $includes, 'master.conf'],
        root_dir  => $root_dir,
        use_ssl   => $use_ssl,
    }

    file { "/etc/postgresql/${pgversion}/main/master.conf":
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('postgresql/master.conf.erb'),
        require => Package["postgresql-${pgversion}"],
    }

    if $ensure == 'present' {
        exec { 'pg-initdb':
            command => "/usr/lib/postgresql/${pgversion}/bin/initdb --locale ${locale} -D ${data_dir}",
            user    => 'postgres',
            unless  => "/usr/bin/test -f ${data_dir}/PG_VERSION",
            require => Class['postgresql::server'],
        }
    }
}
