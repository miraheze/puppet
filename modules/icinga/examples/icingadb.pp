include icinga::repos

class { 'icinga::db':
  db_type         => 'mysql',
  db_pass         => 'icingadb',
  manage_database => true,
}
