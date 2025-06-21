# Example for a dedicated Icinga Web instance for the examples in
# examples/mysql/server1-icingadb.pp and server2-icingadb.pp.
# For TLS base example use hiera data in examples/mysql/data/web.icinga.com.yaml.

host { 'db.icinga.com':
  ip => '192.168.6.10',
}

host { 'server1.icinga.com':
  ip => '192.168.6.11',
}

host { 'server2.icinga.com':
  ip => '192.168.6.12',
}

class { 'icinga::repos':
  manage_epel   => true,
  manage_extras => true,
}

class { 'icinga::web':
  db_type            => 'mysql',
  db_host            => 'db.icinga.com',
  db_pass            => Sensitive('icingaweb2'),
  default_admin_user => 'admin',
  default_admin_pass => Sensitive('admin'),
  manage_database    => false,
  api_host           => ['server1.icinga.com', 'server2.icinga.com'],
  api_pass           => Sensitive('icingaweb2'),
}

class { 'icinga::web::icingadb':
  db_type              => 'mysql',
  db_host              => 'db.icinga.com',
  db_pass              => Sensitive('icingadb'),
  redis_primary_host   => '192.168.6.11',
  redis_primary_pass   => 'redis',
  redis_secondary_host => '192.168.6.12',
  redis_secondary_pass => 'redis',
}

class { 'icinga::web::director':
  db_type         => 'mysql',
  db_host         => 'db.icinga.com',
  db_pass         => Sensitive('director'),
  manage_database => false,
  endpoint        => 'server1.icinga.com',
  api_host        => '192.168.6.11',
  api_pass        => Sensitive('director'),
}

#class { 'icinga::web::reporting':
#  db_type         => 'mysql',
#  db_host         => 'db.icinga.com',
#  db_pass         => Sensitive('reporting'),
#  manage_database => false,
#}
