# Class: postgresql::postgis
#
# This class installs postgis packages
#
# Parameters:
#
# Actions:
#     Install postgis
#
# Requires:
#
# Sample Usage:
#     include postgresql::postgis
#
class postgresql::postgis(
    VMlib::Ensure $ensure = 'present',
    String $postgresql_postgis_package = $::lsbdistcodename ? {
        'buster'  => 'postgresql-11-postgis-2.5',
        'stretch' => 'postgresql-9.6-postgis-2.3',
        'jessie'  => 'postgresql-9.4-postgis-2.3',
    },
) {
    package { [
        $postgresql_postgis_package,
        "${postgresql_postgis_package}-scripts",
        'postgis',
    ]:
        ensure  => $ensure,
    }
}
