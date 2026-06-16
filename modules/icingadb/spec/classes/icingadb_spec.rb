# frozen_string_literal: true

require 'spec_helper'

describe 'icingadb' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with defaults' do
        let(:params) { { db_password: 'supersecret' } }

        it { is_expected.to contain_package('icingadb') }
        it { is_expected.not_to contain_class('icinga::repos') }

        it {
          is_expected.to contain_file('/etc/icingadb/config.yml').with(
            {
              'owner' => 'icingadb',
              'group' => 'icingadb',
              'mode' => '0640',
            },
          ).with_content(%r{database:\n  type: mysql\n  host: localhost\n  database: icingadb\n  user: icingadb\n  password: supersecret\nredis:\n  host: localhost\n  port: 6380\n})
        }

        it { is_expected.not_to contain_file('/etc/icingadb/config.yml').with_content(%r{^retention:}) }
        it { is_expected.not_to contain_exec('icingadb-mysql-import-schema') }
        it { is_expected.to contain_service('icingadb').with('ensure' => 'running', 'enable' => true) }
      end

      context 'with ensure => stopped, enable => false, manage_repo => true, manage_package => false' do
        let(:params) do
          {
            db_password: 'supersecret',
            ensure: 'stopped',
            enable: false,
            manage_repos: true,
            manage_packages: false,
          }
        end

        it { is_expected.to contain_class('icinga::repos') }
        it { is_expected.not_to contain_package('icingadb') }
        it { is_expected.to contain_service('icingadb').with('ensure' => 'stopped', 'enable' => false) }
      end

      context 'with redis_host => redis.example.org, redis_port => 4711, redis_password => supersecret' do
        let(:params) do
          {
            db_password: 'supersecret',
            redis_host: 'redis.example.org',
            redis_port: 4711,
            redis_password: 'supersecret',
          }
        end

        it {
          is_expected.to contain_file('/etc/icingadb/config.yml').with(
            {
              'owner' => 'icingadb',
              'group' => 'icingadb',
              'mode' => '0640',
            },
          ).with_content(%r{redis:\n  host: redis.example.org\n  port: 4711\n  password: supersecret})
        }
      end

      context 'with MySQL non TLS and no import' do
        let(:params) do
          {
            db_type: 'mysql',
            db_port: 4711,
            db_host: 'db.example.org',
            db_name: 'foo',
            db_username: 'bar',
            db_password: 'supersecret',
            db_use_tls: false,
            import_schema: false,
          }
        end

        it { is_expected.not_to contain_exec('icingadb-mysql-import-schema') }
        it {
          is_expected.to contain_file('/etc/icingadb/config.yml')
            .with_content(%r{database:\n  type: mysql\n  host: db.example.org\n  port: 4711\n  database: foo\n  user: bar\n  password: supersecret\n  tls: false\n})
        }
      end

      context 'with MySQL TLS and import for MariaDB' do
        let(:params) do
          {
            db_type: 'mysql',
            db_password: 'supersecret',
            db_use_tls: true,
            import_schema: 'mariadb',
          }
        end

        it { is_expected.to contain_exec('icingadb-mysql-import-schema').with('command' => %r{--ssl}) }
        it {
          is_expected.to contain_file('/etc/icingadb/config.yml')
            .with_content(%r{database:\n  type: mysql\n  host: localhost\n  database: icingadb\n  user: icingadb\n  password: supersecret\n  tls: true\n})
        }
      end

      context 'with MySQL TLS and import' do
        let(:params) do
          {
            db_type: 'mysql',
            db_password: 'supersecret',
            db_use_tls: true,
            import_schema: 'mysql',
          }
        end

        it { is_expected.to contain_exec('icingadb-mysql-import-schema').with('command' => %r{--ssl-mode}) }
        it {
          is_expected.to contain_file('/etc/icingadb/config.yml')
            .with_content(%r{database:\n  type: mysql\n  host: localhost\n  database: icingadb\n  user: icingadb\n  password: supersecret\n  tls: true\n})
        }
      end

      context 'with PostgreSQL non TLS and no import' do
        let(:params) do
          {
            db_type: 'pgsql',
            db_port: 4711,
            db_host: 'db.example.org',
            db_name: 'foo',
            db_username: 'bar',
            db_password: 'supersecret',
            db_use_tls: false,
            import_schema: false,
          }
        end

        it { is_expected.not_to contain_exec('icingadb-pgsql-import-schema') }
        it {
          is_expected.to contain_file('/etc/icingadb/config.yml')
            .with_content(%r{database:\n  type: pgsql\n  host: db.example.org\n  port: 4711\n  database: foo\n  user: bar\n  password: supersecret\n  tls: false\n})
        }
      end

      context 'with PostgreSQL TLS and import' do
        let(:params) do
          {
            db_type: 'pgsql',
            db_password: 'supersecret',
            db_use_tls: true,
            import_schema: true,
          }
        end

        it { is_expected.to contain_exec('icingadb-pgsql-import-schema').with('environment' => ['PGPASSWORD=supersecret']) }
        it {
          is_expected.to contain_file('/etc/icingadb/config.yml')
            .with_content(%r{database:\n  type: pgsql\n  host: localhost\n  database: icingadb\n  user: icingadb\n  password: supersecret\n  tls: true\n})
        }
      end
    end
  end
end
