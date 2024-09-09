class profile::mattermost_from_pkg {
  # PostgreSQL
  class { 'postgresql::globals':
    manage_package_repo => true,
    version             => '9.4',
  }
  class { 'postgresql::server':
    ipv4acls => ['host all all 127.0.0.1/32 md5'],
  }
  postgresql::server::db { 'mattermost':
    user     => 'mattermost',
    password => postgresql_password('mattermost', 'mattermost'),
  }
  postgresql::server::database_grant { 'mattermost':
    privilege => 'ALL',
    db        => 'mattermost',
    role      => 'mattermost',
  }

  # Repo
  yumrepo { 'harbottle-main':
    baseurl  => 'https://copr-be.cloud.fedoraproject.org/results/harbottle/main/epel-7-$basearch/',
    descr    => 'harbottle-main',
    gpgcheck => true,
    gpgkey   => 'https://copr-be.cloud.fedoraproject.org/results/harbottle/main/pubkey.gpg',
  }

  # Mattermost
  class { 'mattermost':
    install_from_pkg     => true,
    version              => latest,
    conf                 => '/etc/mattermost/config.json',
    override_env_options => {
      'MM_SQLSETTINGS_DRIVERNAME' => 'postgres',
      'MM_SQLSETTINGS_DATASOURCE' => 'postgres://mattermost:mattermost@127.0.0.1:5432/mattermost?sslmode=disable&connect_timeout=10',
      'MM_TEAMSETTINGS_SITENAME'  => 'Dev Team',
    },
    require              =>[
      Postgresql::Server::Db['mattermost'],
      Postgresql::Server::Database_grant['mattermost'],
      Yumrepo['harbottle-main'],
    ]
  }

  # Nginx
  include nginx

  nginx::resource::server { $facts['networking']['fqdn']:
    listen_port         => 80,
    proxy               => 'http://localhost:8065',
    location_cfg_append => {
      'proxy_http_version'          => '1.1',
      'proxy_set_header Upgrade'    => '$http_upgrade',
      'proxy_set_header Connection' => '"upgrade"',
    },
  }
}
