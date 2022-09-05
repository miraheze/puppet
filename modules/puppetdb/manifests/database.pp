# Class puppetdb::database
#
# Sets up the postgresql database
class puppetdb::database(
    Optional[String] $master = undef
) {
    $pgversion = $::lsbdistcodename ? {
        'bullseye' => '13',
    }

    $puppetdb_pass = lookup('puppetdb::password::rw')

    # We do this for the require in postgres::db
    $require_class = 'postgresql::master'

    # Postgres replication and users
    $postgres_users = lookup('puppetdb::postgres_users', {'default_value' => undef})
    if $postgres_users {
        $postgres_users_defaults = {
            pgversion => $pgversion,
            master    => true,
        }
        create_resources(postgresql::user, $postgres_users,
            $postgres_users_defaults)
    }

    # sudo -u postgres sh
    # createuser -DRSP puppetdb
    # createdb -E UTF8 -O puppetdb puppetdb
    # exit

    # Create the puppetdb user for localhost
    # This works on every server and is used for read-only db lookups
    postgresql::user { 'puppetdb@localhost':
        ensure   => present,
        user     => 'puppetdb',
        database => 'puppetdb',
        password => $puppetdb_pass,
        master   => true,
    }

    # Create the database
    postgresql::db { 'puppetdb':
        owner   => 'puppetdb',
        require => Class[$require_class],
    }

    # sudo -u postgres sh
    # psql
    # CREATE EXTENSION pg_trgm;
    # \q
    # exit
    #
    exec { 'create_tgrm_extension':
        command => '/usr/bin/psql puppetdb -c "create extension pg_trgm"',
        unless  => '/usr/bin/psql puppetdb -c \'\dx\' | /bin/grep -q pg_trgm',
        user    => 'postgres',
        require => Postgresql::Db['puppetdb'],
    }

}
