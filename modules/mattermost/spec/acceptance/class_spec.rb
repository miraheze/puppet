require 'spec_helper_acceptance'

describe 'mattermost:', unless: UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do
  it 'should run successfully' do
    pp = '
class { "postgresql::globals":
  manage_package_repo => true,
  version             => "9.4",
} ->
class { "postgresql::server":
  ipv4acls => ["host all all 127.0.0.1/32 md5"],
}
postgresql::server::db { "mattermost":
   user     => "mattermost",
   password => postgresql_password("mattermost", "mattermost"),
}
postgresql::server::database_grant { "mattermost":
  privilege => "ALL",
  db        => "mattermost",
  role      => "mattermost",
} ->
class { "mattermost":
  override_options => {
    "SqlSettings" => {
      "DriverName" => "postgres",
      "DataSource" => "postgres://mattermost:mattermost@127.0.0.1:5432/mattermost?sslmode=disable&connect_timeout=10",
    },
  },
}
class { "nginx": }
nginx::resource::upstream { "mattermost":
  members => [ "localhost:8065" ],
}
nginx::resource::server { "mattermost":
  server_name         => [ "myserver.mydomain" ],
  proxy               => "http://mattermost",
  location_cfg_append => {
    "proxy_http_version"          => "1.1",
    "proxy_set_header Upgrade"    => \'$http_upgrade\',
    "proxy_set_header Connection" => \'"upgrade"\',
  },
}
'
    # Apply twice to ensure no errors the second time.
    apply_manifest(pp, catch_failures: true, debug: 'true') do |r|
      expect(r.stderr).not_to match(%r{error}i)
    end
    apply_manifest(pp, catch_failures: true) do |r|
      expect(r.stderr).not_to eq(%r{error}i)
    end
    apply_manifest(pp, catch_failures: true) do |r|
      expect(r.stderr).not_to eq(%r{error}i)
      expect(r.exit_code).to be_zero
    end
  end
end
