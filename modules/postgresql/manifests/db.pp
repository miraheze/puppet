#
# Definition: postgresql::db
#
# Manages a PostgreSQL database.
#
# Parameters:
#
# [*ensure*]
#   'present' to create the database, 'absent' to delete it
#
# [*owner*]
#   User who will own the database (defaults to 'postgres')
#
# Actions:
#   Create/drop database
#
# Requires:
#   Class['postgresql::server']
#
# Sample Usage:
#  postgresql::db { 'mydb': }
#
define postgresql::db(
    Stdlib::Ensure $ensure    = present,
    String $owner     = 'postgres',
) {
    require ::postgresql::server

    $name_safe = regsubst($title, '[\W_]', '_', 'G')

    $db_sql = "SELECT datname from pg_catalog.pg_database where datname = '${name_safe}'"
    $db_exists = "/usr/bin/test -n \"\$( /usr/bin/psql -At -c \"${db_sql}\")\""

    if $ensure == 'present' {
        exec { "create_postgres_db_${name_safe}":
            command => "/usr/bin/createdb --owner='${owner}' '${title}'",
            unless  => $db_exists,
            user    => 'postgres',
        }
    } else {
        exec { "drop_postgres_db_${name_safe}":
            command => "/usr/bin/dropdb '${title}'",
            onlyif  => $db_exists,
            user    => 'postgres',
        }
    }
}
