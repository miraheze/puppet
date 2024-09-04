class profile::mattermost {
  # PostgreSQL
  class { 'postgresql::globals':
    manage_package_repo => true,
    version             => '9.4',
    encoding            => 'UTF-8',
    locale              => 'en_US.UTF-8',
  }
  class { 'postgresql::server':
    ipv4acls => ['host all all 127.0.0.1/32 md5'],
  }
  -> postgresql::server::db { 'mattermost':
    user     => 'mattermost',
    password => postgresql_password('mattermost', 'mattermost'),
  }
  -> postgresql::server::database_grant { 'mattermost':
    privilege => 'ALL',
    db        => 'mattermost',
    role      => 'mattermost',
  }

  # Mattermost
  -> class { 'mattermost':
    override_options => {
      'SqlSettings' => {
        'DriverName' => 'postgres',
        'DataSource' => "postgres://mattermost:mattermost@127.0.0.1:5432/mattermost?sslmode=disable&connect_timeout=10",
      },
      'TeamSettings' => {
        'SiteName' => 'Dev Team',
      },
    },
  }

  # Nginx
  include nginx

  nginx::resource::server { $::fqdn:
    listen_port         => 80,
    proxy               => 'http://localhost:8065',
    location_cfg_append => {
      'proxy_http_version'          => '1.1',
      'proxy_set_header Upgrade'    => '$http_upgrade',
      'proxy_set_header Connection' => '"upgrade"',
    },
  }
}
