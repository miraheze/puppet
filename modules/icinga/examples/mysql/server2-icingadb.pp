# Example for Icinga HA for server2.icinga.com as config server
# and server1.icinga2.com as secondary server.
# Notice: The example for db.icinga.com in examples/mysql/database.pp is TLS based.
# For TLS base example use hiera data in examples/mysql/data/.

host { 'db.icinga.com':
  ip => '192.168.6.10',
}

class { 'icinga::repos':
  manage_epel   => true,
  manage_extras => true,
}

class { 'icinga::server':
  ca_server            => '192.168.6.11',
  colocation_endpoints => { 'server1.icinga.com' => { 'host' => '192.168.6.11', } },
  workers              => {},
  global_zones         => ['global-templates', 'linux-commands', 'windows-commands'],
  web_api_pass         => Sensitive('icingaweb2'),
  director_api_pass    => Sensitive('director'),
  run_web              => true,
}

class { 'icinga::db':
  db_type         => 'mysql',
  db_host         => 'db.icinga.com',
  db_pass         => Sensitive('icingadb'),
  manage_database => false,
  redis_bind      => ['127.0.0.1', '192.168.6.12'],
  redis_pass      => Sensitive('redis'),
}
