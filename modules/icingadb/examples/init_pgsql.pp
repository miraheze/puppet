class { 'postgresql::server':
  password_encryption => 'scram-sha-256',
}

postgresql::server::db { 'icingadb':
  user     => 'icingadb',
  password => 'supersecret',
}

postgresql::server::extension { 'icingadb-citext':
  extension    => 'citext',
  database     => 'icingadb',
  package_name => 'postgresql-contrib',
}

-> class { 'icingadb::redis':
  manage_repos => true,
  requirepass  => Sensitive('supersecret'),
}

-> class { 'icingadb':
  db_type        => 'pgsql',
  db_password    => Sensitive('supersecret'),
  redis_password => Sensitive('supersecret'),
  import_schema  => true,
}
